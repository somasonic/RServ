require 'lib/command'

module RServ::Protocols
	class TS6
		attr_reader :name
		def initialize
			@name = String.new
			@capab = Hash.new
			@link = nil

			$event.add(self, :on_start, "link::start")
      $event.add(self, :on_input, "link::input")
      $event.add(self, :on_close, "link::close")
      $event.add(self, :on_output, "proto::out")
		end

		def on_start(link)
			@link = link
			send("PASS #{$config['link']['password']} TS 6 :#{$config['link']['serverid']}") # PASS password TS ts-ver SID
			send("CAPAB :QS ENCAP SAVE RSFNC SERVICES") # Services to identify as a service
			send("SERVER #{$config['link']['name']} 0 :#{$config['link']['description']}")
		end		
		
		def on_output(line)
			send(line)
		end
		
		def on_close(link)
			@link = nil
			RServ::Link.new($config['server']['addr'], $config['server']['port'])
		end

		def on_input(line)
			line.chomp!
			$log.debug("<---| #{line}")
			puts "<---| #{line}"
			if line =~ /^PING :(.*)$/
				send("PONG :#{$1}")
			elsif line =~ /^SVINFO \d \d \d :(\d{10})$/
				t = Time.now.to_i
				if [t - 1, t, t + 1].include?($1.to_i)
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
			puts "--->| #{text}"
			@link.send(text) if @link
		end
	end
end

RServ::Protocols::TS6.new
