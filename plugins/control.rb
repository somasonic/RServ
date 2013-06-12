class Control < RServ::Plugin
  
  def initialize
    @control = RServ::IRC::PsuedoClient.new("RubyServices", "rserv", "rserv.interlinked.me", "RServ Services", "SZ", ["#services"])
    @channel = "#services"
        
    $event.add(self, :on_input, "link::input")
  end
  
  def on_unload
    @control.quit
  end
  
  def on_input(line)
    if line =~ /:(\w{9}) PRIVMSG (#\w+) :(\w+)\S{0,1} (.*)$/i
      return unless $2 == @channel
      return unless $3.downcase == @control.nick.downcase
      user = $protocol.get_uid($1)
      if user.oper?
        command(user, $4)
      else
        chan("Sorry, you are not an IRC operator.")
      end
    end
  end    
  
  def command(user, command)
    if command =~ /^eval (.*)$/i
      begin
        result = eval($1)
        chan("=> #{result.to_s}")
      rescue => e
        chan("!| #{e}")
        chan("=> #{$1}")
        chan("!| #{e}")
        chan("!| #{e.backtrace.join("\n")}")
      end
    elsif command =~ /^load (\w+)$/i
      begin
        RServ::Plugin.load($1)
        chan("Plugin #{$1} loaded successfully.")
      rescue LoadError => e
        chan("Error loading plugin #{$1}: #{e}")
      end
    elsif command =~ /^unload (\w+)$/i
      begin
        RServ::Plugin.unload($1)
        chan("Plugin #{$1} unloaded successfully.")
      rescue => e
        chan("Error unloading plugin #{$1}: #{e}")
      end
    end
  end
  
  def chan(msg)
    @control.privmsg(@channel, msg)
  end
end
