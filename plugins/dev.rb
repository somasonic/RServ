class Dev < RServ::Plugin
  def initialize
    puts 3
    @name = "Dev"
    @trackchan = "#services"
    @host = "Development!service@services"]

    #send(":#{$config['link']['name']} NICK #{Time.now.to_i} Development services services service + 127.0.0.1 :Development Service")
    #send(":#{@host} JOIN #{@trackchan}")
  end

=begin
  def on_privmsg(cmd)
    to = cmd.params[0]
    msg = cmd.params[1].split
    if to == @trackchan
      if msg[0] == "eval"
        result = eval(msg[1..-1].join(" ")).split("\\r\\n")
        result.each {|r| send(":#{@host} PRIVMSG #{@trackchan} :#{r}")}
      end
    end
  end
=end
end
