# encoding: UTF-8
require 'pp'
require 'elif'
require 'time'

module TwitterToCsv
  class CsvBuilder
    attr_accessor :options, :sampled_fields

    def initialize(options = {})
      @options = options
      @sampled_fields = {}
      @num_samples = 0
      @retweet_counts = {}
      @retweet_hour_counts = {}
    end

    def run(&block)
      log_csv_header if options[:csv] && !options[:csv_appending]
      if options[:replay_from_file]
        replay_from options[:replay_from_file], &block
      else
        begin
          TwitterWatcher.new(options).run do |status|
            handle_status status
          end
        rescue SignalException, SystemExit
          EventMachine::stop_event_loop
          exit
        rescue StandardError => e
          STDERR.puts "\nException #{e.message}:\n#{e.backtrace.join("\n")}\n\n"
          STDERR.puts "Waiting for a couple of minutes..."
          sleep 120
          retry
        end
      end
    end

    def within_time_window(status)
      if options[:start] || options[:end]
        created_at = status['created_at'].is_a?(Time) ? status['created_at'] : Time.parse(status['created_at'])
        return false if options[:start] && created_at < options[:start]
        return false if options[:end] && created_at >= options[:end]
      end
      true
    end

    def display_rolledup_status?(status)
      created_at = status['created_at'].is_a?(Time) ? status['created_at'] : Time.parse(status['created_at'])
      @newest_status_at = created_at if @newest_status_at.nil?

      if status['retweeted_status'] && status['retweeted_status']['id']
        # This is a retweet.
        original_created_at = status['retweeted_status']['created_at'].is_a?(Time) ? status['retweeted_status']['created_at'] : Time.parse(status['retweeted_status']['created_at'])
        if !options[:retweet_window] || created_at <= original_created_at + options[:retweet_window] * 60 * 60 * 24
          @retweet_counts[status['retweeted_status']['id']] ||= 0
          @retweet_counts[status['retweeted_status']['id']] = status['retweeted_status']['retweet_count'] if status['retweeted_status']['retweet_count'] > @retweet_counts[status['retweeted_status']['id']]


          if options[:retweet_counts_at]
            @retweet_hour_counts[status['retweeted_status']['id']] ||= options[:retweet_counts_at].map { 0 }
            options[:retweet_counts_at].each.with_index do |hour_mark, index|
              if created_at <= original_created_at + hour_mark * 60 * 60 && status['retweeted_status']['retweet_count'] > @retweet_hour_counts[status['retweeted_status']['id']][index]
                @retweet_hour_counts[status['retweeted_status']['id']][index] = status['retweeted_status']['retweet_count']
              end
            end
          end
        end
        false
      else
        # This is an original status.
        if (@retweet_counts[status['id']] || 0) >= (options[:retweet_threshold] || 0)
          if !options[:retweet_window] || created_at <= @newest_status_at - options[:retweet_window] * 60 * 60 * 24
            status['retweet_count'] = @retweet_counts[status['id']] if @retweet_counts[status['id']] && @retweet_counts[status['id']] > status['retweet_count']
            status['_retweet_hour_counts'] = @retweet_hour_counts.delete(status['id']) if options[:retweet_counts_at]
            true
          else
            false
          end
        else
          false
        end
      end
    end

    def handle_status(status, &block)
      if (options[:require_english] && is_english?(status)) || !options[:require_english]
        if within_time_window(status)
          if options[:retweet_mode] != :rollup || display_rolledup_status?(status)
            log_json(status) if options[:json]
            log_csv(status) if options[:csv]
            yield_status(status, &block) if block
            sample_fields(status) if options[:sample_fields]
            analyze_gaps(status, options[:analyze_gaps]) if options[:analyze_gaps]
            STDERR.puts "Logging: #{status['text']}" if options[:verbose]
          end
        end
      end
    end

    def log_csv_header
      header_labels = options[:fields].dup

      header_labels += ["average_sentiment", "sentiment_words"] if options[:compute_sentiment]
      header_labels << "word_count" if options[:compute_word_count]

      options[:retweet_counts_at].each { |hours| header_labels << "retweets_at_#{hours}_hours" } if options[:retweet_counts_at]

      options[:url_columns].times { |i| header_labels << "url_#{i+1}" } if options[:url_columns] && options[:url_columns] > 0
      options[:hashtag_columns].times { |i| header_labels << "hash_tag_#{i+1}" } if options[:hashtag_columns] && options[:url_columns] > 0
      options[:user_mention_columns].times { |i| header_labels << "user_mention_#{i+1}" } if options[:user_mention_columns] && options[:user_mention_columns] > 0

      options[:csv].puts header_labels.to_csv(:encoding => 'UTF-8', :force_quotes => true)
    end

    def log_csv(status)
      options[:csv].puts output_row(status).to_csv(:encoding => 'UTF-8', :force_quotes => true)
    end

    def yield_status(status, &block)
      block.call output_row(status)
    end

    def output_row(status)
      row = options[:fields].map do |field|
        field.split(".").inject(status) { |memo, segment|
          memo && memo[segment]
        }.to_s
      end

      row += compute_sentiment(status["text"]) if options[:compute_sentiment]

      row << status["text"].split(/\s+/).length if options[:compute_word_count]

      row += status["_retweet_hour_counts"] if options[:retweet_counts_at]

      if options[:url_columns] && options[:url_columns] > 0
        urls = (status["entities"] && (status["entities"]["urls"] || []).map {|i| i["expanded_url"] || i["url"] }) || []
        options[:url_columns].times { |i| row << urls[i].to_s }
      end

      if options[:hashtag_columns] && options[:hashtag_columns] > 0
        hashes = (status["entities"] && (status["entities"]["hashtags"] || []).map {|i| i["text"] }) || []
        options[:hashtag_columns].times { |i| row << hashes[i].to_s }
      end

      if options[:user_mention_columns] && options[:user_mention_columns] > 0
        users = (status["entities"] && (status["entities"]["user_mentions"] || []).map {|i| i["screen_name"] }) || []
        options[:user_mention_columns].times { |i| row << users[i].to_s }
      end

      row
    end

    def afinn
      @afinn_cache ||= begin
        words_or_phrases = []
        File.read(File.expand_path(File.join(File.dirname(__FILE__), "afinn", "AFINN-111.txt"))).each_line do |line|
          word_or_phrase, valence = line.split(/\t/)
          pattern = Regexp::escape word_or_phrase.gsub(/-/, " ").gsub(/'/, '')
          words_or_phrases << [/\b#{pattern}\b/i, pattern.length, valence.to_f]
        end
        words_or_phrases.sort {|b, a| a[1] <=> b[1] }
      end
    end

    def compute_sentiment(original_text)
      text = original_text.downcase.gsub(/'/, '').gsub(/[^a-z0-9]/, ' ').gsub(/\s+/, ' ').strip
      count = 0
      valence_sum = 0
      afinn.each do |pattern, length, valence|
        while text =~ pattern
          text.sub! pattern, ''
          valence_sum += valence
          count += 1
        end
      end
      if count > 0
        [valence_sum / count.to_f, count]
      else
        [0, 0]
      end
    end

    def replay_from(filename, &block)
      # If a retweet mode is being used, we read the file backwards using the Elif gem.
      opener = options[:retweet_mode] ? Elif : File

      opener.open(filename, "r") do |file|
        file.each do |line|
          next if line =~ /\A------SEP.RATOR------\Z/i
          handle_status JSON.parse(line), &block
        end
      end
      puts "Last status seen at #{@last_status_seen_at}." if options[:analyze_gaps] && @last_status_seen_at
    end

    def analyze_gaps(status, min_gap_size_in_minutes)
      time = Time.parse(status['created_at'])
      if !@last_status_seen_at
        puts "First status seen at #{time}."
      else
        gap_length = (time - @last_status_seen_at) / 60
        if gap_length > min_gap_size_in_minutes
          puts "Gap of #{gap_length.to_i} minutes from #{@last_status_seen_at} to #{time}."
        end
      end
      @last_status_seen_at = time
    end

    def sample_fields(status)
      extract_fields(status, sampled_fields)
      @num_samples += 1
      if @num_samples > options[:sample_fields]
        puts "Sampled fields from Twitter:"
        sampled_fields.each do |field, count|
          puts " #{field} #{' ' * [60 - field.length, 0].max} #{count}"
        end
        exit 1
      end
    end

    def extract_fields(object, fields, current_path = [])
      if object.is_a?(Hash)
        object.each do |k, v|
          extract_fields v, fields, current_path + [k]
        end
      else
        path = current_path.join(".")
        fields[path] ||= 0
        fields[path] += 1
      end
    end

    def log_json(status)
      options[:json].puts JSON.dump(status) #JSON.pretty_generate(status)
      options[:json].puts "------SEPARATOR------"
      options[:json].flush
    end

    def is_english?(status)
      if status.has_key?('delete')
        STDERR.puts "Skipping Tweet with delete." if options[:verbose]
        return false
      end

      if status['text'] =~ /[^[:ascii:]]/
        STDERR.puts "Skipping \"#{status['text']}\" due to non-ascii text." if options[:verbose]
        return false
      end

      unless status['user']['lang'] == "en"
        STDERR.puts "Skipping \"#{status['text']}\" due to lang of #{status['user']['lang']}." if options[:verbose]
        return false
      end

      unless UnsupervisedLanguageDetection.is_english_tweet?(status['text'])
        STDERR.puts "Skipping \"#{status['text']}\" due to UnsupervisedLanguageDetection guessing non-English" if options[:verbose]
        return false
      end

      true
    end
  end
end
