require 'lib/command'

module RServ::Protocols
	class TS6
		attr_reader :name
		def initialize
			@name = String.new
			@capab = Hash.new
			@modules = Array.new
			@link = nil

			$event.add(self, :on_start, "link::start")
      $event.add(self, :on_input, "link::input")
      $event.add(self, :on_close, "link::close")
      $event.add(self, :on_output, "proto::out")
		end

		def on_start(link)
			@link = link
			send("PASS #{$config['link']['password']} TS 6 #{$config['link']['serverid']}") # PASS password TS ts-ver SID
			send("CAPAB QS ENCAP SERVICES") # Services to identify as a service
			send("SERVER #{$config['link']['name']} 0 #{$config['link']['description']}")
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
			if line =~ /^PING :(\d{2}\w{1}) (\d{2}\w{1})?/
				send("PONG :#{$1}")
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
