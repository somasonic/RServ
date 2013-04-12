require 'lib/command'

module RServ::Protocols
	class TS6
		attr_reader :name
		def initialize
			@name = String.new
			@capab = Hash.new
			@link = nil
      @last_pong, @last_ping = 0, 0
      @connected = false

			$event.add(self, :on_start, "link::start")
      $event.add(self, :on_input, "link::input")
      $event.add(self, :on_close, "link::close")
      $event.add(self, :on_output, "proto::out")
      $event.add(self, :on_pong, "cmd::pong")
		end

		def on_start(link)
			@link = link
      $log.info "Connected to #{$config['server']['addr']}, sending PASS, CAPAB and SERVER"
			send("PASS #{$config['link']['password']} TS 6 :#{$config['link']['serverid']}") # PASS password TS ts-ver SID
			send("CAPAB :QS ENCAP SAVE RSFNC SERVICES") # Services to identify as a service
			send("SERVER #{$config['link']['name']} 0 :#{$config['link']['description']}")        
      
      while @connected == false
        sleep 5
      end 
      
      RServ::Timer.new(120) do # ping those people
        diff = Time.now.to_i - @last_pong
        if diff > 120
          send("PING :#{$config['link']['serverid']}")
          @last_ping = Time.now.to_i
          $log.info "Pinging #{$config['server']['addr']}"
        end
      end
      
		end		
		
		def on_output(line)
			send(line)
		end
		
		def on_close(link)
			@link = nil
      @connected = false
      $log.info "Link closed, starting new link with #{$config['server']['addr']}:#{$config['server']['port']}..."
      sleep 3
			RServ::Link.new($config['server']['addr'], $config['server']['port'], true)
		end

		def on_input(line)
			line.chomp!
			$log.debug("<---| #{line}")
			if line =~ /^PING :(.*)$/
				send("PONG :#{$1}")
      elsif line =~ /^PONG :/
        @last_pong = Time.now.to_i
        diff = @last_ping - @last_pong
        $log.info "Pong received, #{diff} seconds after ping"
			elsif line =~ /^SVINFO \d \d \d :(\d{10})$/
				t = Time.now.to_i
				if [t - 1, t, t + 1].include?($1.to_i)
          @connected = true
					send("SVINFO 6 6 0 :#{t}")
				else
					$log.fatal "Servers out of sync. Remote time: #{$1}, our time: #{t}. Exiting."
					exit
				end
			end
		end

		private

		def send(text)
			$log.debug("--->| #{text}")
			@link.send(text) if @link
		end
	end
end

RServ::Protocols::TS6.new
