class Control < RServ::Plugin
  
  def initialize
    @control = RServ::IRC::PsuedoClient.new("RServ", "rserv", "rserv.interlinked.me", "RServ Services", "SZ", ["#rserv", "#services"])
        
    $event.add(self, :on_input, "link::input")
  end
  
  def on_unload
    @control.quit
  end
  
  def on_input(line)
    if line =~ /:(\w{9}) PRIVMSG (#\w+) :(\w+)\S{0,1} (.*)$/i
      return unless @control.channels.include?($2)
      return unless $3.downcase == @control.nick.downcase
      c = $2
      user = $protocol.get_uid($1)
      if user.oper?
        command(c, user, $4)
      else
        msg(c, "Sorry, you are not an IRC operator.")
      end
    end
  end    
  
  def command(c, user, command)
    if command =~ /^eval (.*)$/i
      begin
        result = eval($1)
        msg(c, "=> #{result.to_s}")
      rescue => e
        msg(c, "!| #{e}")
        msg(c, "=> #{$1}")
        msg(c, "!| #{e}")
        msg(c, "!| #{e.backtrace.join("\n")}")
      end
    elsif command =~ /^load (\w+)$/i
      begin
        RServ::Plugin.load($1)
        msg(c, "Plugin #{$1} loaded successfully.")
      rescue LoadError => e
        msg(c, "Error loading plugin #{$1}: #{e}")
      end
    elsif command =~ /^unload (\w+)$/i
      begin
        RServ::Plugin.unload($1)
        msg(c, "Plugin #{$1} unloaded successfully.")
      rescue => e
        msg(c, "Error unloading plugin #{$1}: #{e}")
      end
    end
  end
  
  def msg(t, msg)
    @control.privmsg(t, msg)
  end
end
