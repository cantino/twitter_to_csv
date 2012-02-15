module TwitterToCsv
  class CsvBuilder
    attr_accessor :options

    def initialize(options = {})
      @options = options
    end
    
    def run
      begin
        TwitterWatcher.new(options).run do |status|
          if options[:json]
            options[:json].puts JSON.dump(status) #JSON.pretty_generate(status)
            options[:json].puts "------SEPERATOR------"
            options[:json].flush
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