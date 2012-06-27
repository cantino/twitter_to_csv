# encoding: UTF-8
require 'pp'
require 'elif'
require 'time'

module TwitterToCsv
  class CsvBuilder
    attr_accessor :options, :sampled_fields

    # http://daringfireball.net/2010/07/improved_regex_for_matching_urls
    URL_REGEX = %r"\b((?:https?://|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}/)(?:[^\s\(\)<>]+|\((?:[^\s\(\)<>]+|(?:\([^\s\(\)<>]+\)))*\))+(?:\((?:[^\s\(\)<>]+|(?:\([^\s\(\)<>]+\)))*\)|[^\s\`\!\(\)\[\]\{\};:'\".,<>\?«»“”‘’]))"i

    def initialize(options = {})
      @options = options
      @sampled_fields = {}
      @num_samples = 0
      @retweet_counts = {}
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

    def display_rolledup_status?(status)
      created_at = status['created_at'].is_a?(Time) ? status['created_at'] : Time.parse(status['created_at'])
      @newest_status_at = created_at if @newest_status_at.nil?

      if status['retweeted_status'] && status['retweeted_status']['id']
        # This is a retweet.
        original_created_at = status['retweeted_status']['created_at'].is_a?(Time) ? status['retweeted_status']['created_at'] : Time.parse(status['retweeted_status']['created_at'])
        if !options[:retweet_window] || original_created_at >= created_at - options[:retweet_window] * 60 * 60 * 24
          @retweet_counts[status['retweeted_status']['id']] ||= 0
          @retweet_counts[status['retweeted_status']['id']] = status['retweeted_status']['retweet_count'] if status['retweeted_status']['retweet_count'] > @retweet_counts[status['retweeted_status']['id']]
        end
        false
      else
        # This is an original status.
        if (@retweet_counts[status['id']] || 0) >= (options[:retweet_threshold] || 0)
          if !options[:retweet_window] || created_at <= @newest_status_at - options[:retweet_window] * 60 * 60 * 24
            status['retweet_count'] = @retweet_counts[status['id']] if @retweet_counts[status['id']] && @retweet_counts[status['id']] > status['retweet_count']
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

    def log_csv_header
      header_labels = options[:fields].dup

      if options[:url_columns] && options[:url_columns] > 0
        options[:url_columns].times { |i| header_labels << "url_#{i+1}" }
      end

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

      if options[:url_columns] && options[:url_columns] > 0
        urls = status['text'].scan(URL_REGEX).flatten.compact
        options[:url_columns].times { |i| row << urls[i].to_s }
      end

      row
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