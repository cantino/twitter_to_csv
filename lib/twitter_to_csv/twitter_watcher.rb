module TwitterToCsv
  class TwitterWatcher
    attr_accessor :username, :password, :filter, :fetch_errors

    def initialize(options)
      @username = options[:username]
      @password = options[:password]
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
      EventMachine::run do
        stream = Twitter::JSONStream.connect(
          :path    => "/1/statuses/#{(filter && filter.length > 0) ? 'filter' : 'sample'}.json#{"?track=#{filter.join(",")}" if filter && filter.length > 0}",
          :auth    => "#{username}:#{password}",
          :ssl     => true
        )

        stream.each_item do |item|
          handle_status JSON.parse(item), block
        end

        stream.on_error do |message|
          STDERR.puts " --> Twitter error: #{message} <--"
        end

        stream.on_no_data do |message|
          STDERR.puts "-- Got no data for awhile; trying to reconnect."
          stream.unbind
        end

        stream.on_max_reconnects do |timeout, retries|
          STDERR.puts " --> Oops, tried too many times! <--"
          EventMachine::stop_event_loop
        end
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