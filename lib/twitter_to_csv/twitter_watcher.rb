require 'cgi'

module TwitterToCsv
  class TwitterWatcher
    attr_accessor :api_key, :api_secret, :access_token, :access_token_secret, :filter, :fetch_errors

    def initialize(options)
      @api_key = options[:api_key]
      @api_secret = options[:api_secret]
      @access_token = options[:access_token]
      @access_token_secret = options[:access_token_secret]
      @filter = options[:filter]
      @fetch_errors = 0
    end

    def progress(str)
      STDERR.print "#{str}..."
      STDERR.flush
      yield
      STDERR.puts "done."
    end

    def run(&block)
      while true
        EventMachine::run do
          stream = Twitter::JSONStream.connect(
            :path    => "/1/statuses/#{(filter && filter.length > 0) ? 'filter' : 'sample'}.json#{"?track=#{filter.map {|f| CGI::escape(f) }.join(",")}" if filter && filter.length > 0}",
            :ssl     => true,
            :oauth   => {
              :consumer_key    => api_key,
              :consumer_secret => api_secret,
              :access_key      => access_token,
              :access_secret   => access_token_secret
            }
          )

          stream.each_item do |item|
            handle_status JSON.parse(item), block
          end

          stream.on_error do |message|
            STDERR.puts " --> Twitter error: #{message} <--"
          end

          stream.on_no_data do |message|
            STDERR.puts " --> Got no data for awhile; trying to reconnect."
            EventMachine::stop_event_loop
          end

          stream.on_max_reconnects do |timeout, retries|
            STDERR.puts " --> Oops, tried too many times! <--"
            EventMachine::stop_event_loop
          end
        end
        puts " --> Reconnecting..."
      end
    end

    def handle_status(status, block)
      return unless status
      return if status.has_key?('delete')
      return unless status['text']
      status['text'] = status['text'].gsub(/&lt;/, "<").gsub(/&gt;/, ">").gsub(/[\t\n\r]/, '  ')
      block.call(status)
    end
  end
end
