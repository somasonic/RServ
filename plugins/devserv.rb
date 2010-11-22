class DevServ < RServ::Plugin
	def initialize
		sleep 10
		send(":#{$config['link']['name']} EUID DevServ 0 #{Time.now.to_i} + service DevServ 127.0.0.1 00RS00000 DevServ 0 :Development Service")
	end
end
