require 'socket'

module RServ

  # This is the link class, it connects to the
  # socket, loops through input, sends events
  # based on it to the parser.
  class Link
    attr_reader :connected
    def initialize(server, port, do_start = true)
      @connected = false
      @buffer = []
      @socket = nil
      @server = server
      @port = port

      # Events
      $event.add(self, :on_link_start, "link::start")

      start if do_start
    end

    def start
      return @socket if @connected
      @socket = TCPSocket.new(@server, @port)
      $event.send("link::start", self)
    end

    def on_link_start(link)
      if link == self
        @connected = true
        main_loop
        @buffer.each {|b| send(b)}
        @buffer.clear
      else
        @socket.close if @socket
        @connected = false
        $event.unregister(self)
      end
    end

    def send(text)
      if @connected
        @socket.puts text.chomp
      else
        @buffer << text
      end
    end

    private

    def main_loop
      Thread.new do
        while @connected
          begin
            x = @socket.gets
            raise "Disconnected" if x.nil?
            $event.send("link::input", x)
          rescue => boom
            $log.warn "Disconnected from #{@server}:#{@port}."
            @connected = false
            @socket.close
            @socket = nil
            @buffer.clear
            $event.send("link::close", self)
          end
        end
      end
    end
  end
end
