require 'lib/command'

module RServ::Protocols
	class TS6
		attr_reader :name, :established
		def initialize
			@name = String.new
			@link = nil #socket
      @established = false
      @remote_sid = nil
      @remote_name = "unknown.ircserver"
      @last_pong = 0
      
            
			$event.add(self, :on_start, "link::start")
      $event.add(self, :on_input, "link::input")
      $event.add(self, :on_close, "link::close")
      $event.add(self, :on_output, "proto::out")
		end

		def on_start(link)
			@link = link
      sleep 3
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
      $log.fatal "Link closed. Quitting."
      return
    end

		def on_input(line)
			line.chomp!
      sid = $config['link']['serverid']
      name = $config['link']['name']
			$log.debug("<---| #{line}")
      if @established
        
        if line =~ /^:(\w{3}) PING (\S+\.\w+) :(\w{3})$/
          send(":#{sid} PONG #{name} :#{$1}")
          $log.info "Ponging #{$1}"
        elsif line =~ /^SQUIT (\w{3}) :(.*)$/
          $log.info "SQUIT received for our SID: SQUIT #{$1} (#{$2})"
        end
        
        #if line =~ /^:(\w{3}) (\w+) (.*)$/
        #  handle_input($1, $2)
        #else
        #  unhandled_input(line)
        #end
  
      else
        
        #establishing the link
        if line =~ /^PASS (\S+) TS 6 :(\w{3})$/ # todo: make match accept password to config
          @remote_sid = $2
          $log.info "Received PASS"
        elsif line =~ /^PING :(\S+)$/
          if @remote_sid == nil
            $log.fatal "Received SVINFO but have got no SID recorded. Exiting."
            return
          end
		      send("PONG :#{$1}")
          send("PING :#{$config['link']['serverid']}")
        elsif line =~ /^:(\w{3}) PING (\S+\.\w+) :(\w{3})$/
          @remote_name = $2 if $1 == @remote_sid
          send(":#{sid} PONG #{name} :#{$1}")
          $log.info "Received burst PING from SID #{$1}, ponging.."
        elsif line =~ /^SERVER/
          $log.info "Received SERVER, sending SVINFO"
          send("SVINFO 6 6 0 :#{Time.now.to_i}")
        elsif line =~ /^:(\w{3}) PONG (\S+\.\w+) :(\w{3})$/
          if $1 == @remote_sid and $3 == sid
            @established = true
            $event.send("server::connected")
            $log.info "Server connection established to #{$2} (#{$1})!"
          end
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
