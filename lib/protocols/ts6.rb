require 'lib/command'

module RServ::Protocols
	class TS6
		attr_reader :name, :established
		def initialize
			@name = String.new
			@link = nil #socket
      @established = false
      @remote_sid = nil
      @last_pong = 0
      
            
			$event.add(self, :on_start, "link::start")
      $event.add(self, :on_input, "link::input")
      $event.add(self, :on_close, "link::close")
      $event.add(self, :on_output, "proto::out")
		end

		def on_start(link)
			@link = link
      $log.info "Connected to #{$config['server']['addr']}, sending PASS, CAPAB and SERVER"
			send("PASS #{$config['link']['password']} TS 6 :#{$config['link']['serverid']}") # PASS password TS ts-ver SID
			send("CAPAB :QS ENCAP SAVE RSFNC SERVICES") # Services to identify as a service
			send("SERVER #{$config['link']['name']} 0 :#{$config['link']['description']}")              
    end
      		
		def on_output(line)
			send(line)
		end
		
		def on_close(link)
			@link, @remote_sid, @established, @last_pong = nil, nil, false, 0
      $log.info "Link closed, starting new link with #{$config['server']['addr']}:#{$config['server']['port']} in 2 seconds..."
      Thread.new do
        sleep 2
		    RServ::Link.new($config['server']['addr'], $config['server']['port'], true)
      end
		end

		def on_input(line)
			line.chomp!
			$log.debug("<---| #{line}")
      if @established
        
        # process commands after the link is established
        if line =~ /^PING :(\S+)$/
		      send("PONG :#{$1}")
        elsif line =~ /^PONG :(\S+)$/
          # this ping system is a load of crap, oh well
          if @last_pong == 0
            @last_pong = Time.now.to_i
          else
            diff = Time.now.to_i - @last_pong
            if diff > 300
              $log.fatal "Exiting due to ping timeout: 300sec."
              return
            else
              @last_pong = Time.now.to_i
            end
          end
          sleep 300
          send("PING :#{$config['link']['name']}")
        elsif line =~ /^:(\w{3}) (\w+) (.*)$/
          handle_input($1, $2)
        else
          unhandled_input(line)
        end
  
      else
        
        #establishing the link
        if line =~ /^PASS (\S+) TS 6 :(\w{3})$/ # todo: make match accept password to config
          @remote_sid = $2
        elsif line =~ /^PING :(\S+)$/
          if @remote_sid == nil
            $log.fatal "Received SVINFO but have got no SID recorded. Exiting."
            return
          end
		      send("PONG :#{$1}")
          send("PING :#{$config['link']['serverid']}")
          $log.info("Link established with #{@remote_sid}")
          $event.send("link::established", self)
          @established = true
	      elsif line =~ /^SERVER/
          send("SVINFO 6 6 0 :#{Time.now.to_i}")
        end
      end
    end

		private

		def send(text)
			$log.debug("--->| #{text}")
			@link.send(text) if @link
		end
    
    def handle_input(cmd, params)
      if cmd == "PING"
        if params =~ /^(\S+) :(\w{3})$/
          send(":#{$config['link']['serverid']} PONG #{$config['link']['name']} :#{$2}")
        end
      end
    end
    
    def unhandled_input(line)
      $log.info "UNHANDLED INPUT: #{line}"
    end
    
	end
end

RServ::Protocols::TS6.new
