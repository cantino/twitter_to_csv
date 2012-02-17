module TwitterToCsv
  class CsvBuilder
    attr_accessor :options

    def initialize(options = {})
      @options = options
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

    def run
      begin
        TwitterWatcher.new(options).run do |status|
          if (options[:require_english] && is_english?(status)) || !options[:require_english]
            if options[:json]
              options[:json].puts JSON.dump(status) #JSON.pretty_generate(status)
              options[:json].puts "------SEPERATOR------"
              options[:json].flush
            end
            STDERR.puts "Logging: #{status['text']}" if options[:verbose]
          end
        end
      rescue StandardError => e
        STDERR.puts "\nException #{e.message}:\n#{e.backtrace.join("\n")}\n\n"
        STDERR.puts "Waiting for a couple of minutes..."
        sleep 120
        retry
      end
    end
  end
end