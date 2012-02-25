# encoding: UTF-8
require 'pp'

module TwitterToCsv
  class CsvBuilder
    attr_accessor :options, :sampled_fields

    # http://daringfireball.net/2010/07/improved_regex_for_matching_urls
    URL_REGEX = %r"\b((?:https?://|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}/)(?:[^\s\(\)<>]+|\((?:[^\s\(\)<>]+|(?:\([^\s\(\)<>]+\)))*\))+(?:\((?:[^\s\(\)<>]+|(?:\([^\s\(\)<>]+\)))*\)|[^\s\`\!\(\)\[\]\{\};:'\".,<>\?«»“”‘’]))"i

    def initialize(options = {})
      @options = options
      @sampled_fields = {}
      @num_samples = 0
    end

    def run
      log_csv_header if options[:csv] && !options[:csv_appending]
      if options[:replay_from_file]
        replay_from options[:replay_from_file]
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

    def handle_status(status)
      if (options[:require_english] && is_english?(status)) || !options[:require_english]
        log_json(status) if options[:json]
        log_csv(status) if options[:csv]
        sample_fields(status) if options[:sample_fields]
        STDERR.puts "Logging: #{status['text']}" if options[:verbose]
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
      csv_row = options[:fields].map do |field|
        field.split(".").inject(status) { |memo, segment|
          memo && memo[segment]
        }.to_s
      end

      if options[:url_columns] && options[:url_columns] > 0
        urls = status['text'].scan(URL_REGEX).flatten.compact
        options[:url_columns].times { |i| csv_row << urls[i].to_s }
      end

      options[:csv].puts csv_row.to_csv(:encoding => 'UTF-8', :force_quotes => true)
    end

    def replay_from(filename)
      File.open(filename, "r") do |file|
        until file.eof?
          line = file.readline
          next if line =~ /\A------SEP.RATOR------\Z/i
          handle_status JSON.parse(line)
        end
      end
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