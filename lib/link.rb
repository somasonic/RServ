##
# Copyright (C) 2013 Andrew Northall
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated 
# documentation files (the "Software"), to deal in the Software without restriction, including without limitation 
# the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, 
# and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions 
# of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
# TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
# DEALINGS IN THE SOFTWARE.
##

require 'socket'

module RServ

  # This is the link class, it connects to the
  # socket, loops through input, sends events
  # based on it to the parser.
  class Link
    attr_reader :connected
    def initialize(server, port, do_start = false)
      @connected = false
      @buffer = []
      @socket = nil
      @server = server
      @port = port

      # Events
      $event.add(self, :on_link_start, "link::start")
      $event.add(self, :on_shutdown, "shutdown")

      start if do_start
    end

    def start
      return @socket if @connected
      
      @socket = TCPSocket.new(@server, @port)
      if Configru.server.ssl == true
        require 'openssl'
        context = OpenSSL::SSL::SSLContext.new
        context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        @socket = OpenSSL::SSL::SSLSocket.new(@socket, context)
        @socket.sync_close = true
        @socket.connect
      end
      
      $event.send("link::start", self)
    end

    def on_link_start(link)
      if link == self
        @connected = true
        Thread.new { main_loop }
        @buffer.each {|b| send(b)}
        @buffer.clear
      else
        @socket.close if @socket
        @connected = false
        $event.unregister(self)
      end
    end
    
    def on_shutdown
      @socket.close
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
      while @connected
        begin
          x = @socket.gets
          raise "Disconnected" if x.nil?
          $event.send("link::input", x)
        rescue "Disconnected" 
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
