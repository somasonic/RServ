require 'lib/command'

module RServ::Protocols
  class Inspircd11
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
      send("SERVER #{$config['link']['name']} #{$config['link']['password']} 0 :#{$config['link']['gecos']}")
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
      if line =~ /^ERROR :(.+)$/
        $log.fatal "Error from uplink: #{$1}"
        puts "Error from uplink: #{$1}"
        exit
      elsif line =~ /^:#{@name} PING #{$config['link']['name']}/
        send(":#{$config['link']['name']} PONG #{@name}")
      elsif line =~ /^CAPAB (.+)/
        handle_capab($1)
      elsif line =~ /^SERVER ([^\s]+)/
        @name = $1
        send("BURST #{Time.now.to_i}")
        send("ENDBURST")
      elsif line =~ /^ENDBURST$/
      elsif line =~ /^:([^ ]+) +(.*)$/
        cmd = $2.split[0].downcase
        params = parse_params($2.split[1..-1].join(" "))
        c = RServ::Command.new(cmd, params, $1)
        $event.send("cmd::#{cmd.to_s}", c)
      else
        cmd = line.split[0].downcase
        params = parse_params(line.split[1..-1].join(" "))
        c = RServ::Command.new(cmd, params)
        $event.send("cmd::#{cmd.command.downcase}", c)
        puts "cmd::#{cmd.command.downcase}"
      end
    end

    private

    def parse_params(params)
      params, str = params.split(/ +:/, 2)
      params = params.split
      params.push(str) if str
      params
    end

    def send(text)
      @link.send(text) if @link
    end

    def handle_capab(capab)
      capab.chomp!
      if capab =~ /^(START|END)$/
        # ignore
      elsif capab =~ /^CAPABILITIES :(.*)$/
        capabs = $1.split
        capabs.each {|c| c = c.split; @capab[c[0]] = c[1]}
      elsif capab =~ /^MODULES (.*)/
        @modules = $1.split(",")
      end
    end
  end
end

RServ::Protocols::Inspircd11.new
