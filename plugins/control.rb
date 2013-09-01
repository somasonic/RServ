##
# Copyright (C) 2013 Andrew Northall
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated 
# documentation files (the "Software"), to deal in the Software without restriction, including without limitation 
# the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, 
# and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions 
# of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
# TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
# DEALINGS IN THE SOFTWARE.
##

class Control < RServ::Plugin
  
  def initialize
    @control = RServ::IRC::PsuedoClient.new("RServ", "rserv", "#{Configru.link.name}", "RServ Services", "SZ", ["#rserv", "#services", "#opers"])
    @prefix = "@" #change to make the bot respond to different prefixes. make it nil to not use.
    @starttime = Time.now.to_i
        
    $event.add(self, :on_input, "link::input")
  end
  
  def on_unload
    @control.quit
  end
  
  def on_input(line)
    if line =~ /:(\w{9}) PRIVMSG (#\S+) :#{@control.nick}\S{0,1} (.+)$/i
      return unless @control.channels.include?($2)
      c = $2
      user = $protocol.get_uid($1)
      if user.oper?
        command(c, user, $3)
      else
        msg(c, "Sorry, you are not an IRC operator.")
      end
    elsif line =~ /:(\w{9}) PRIVMSG (#\S+) :#{@prefix}(.+)$/i
      return unless @control.channels.include?($2)
      c = $2
      user = $protocol.get_uid($1)
      if user.oper?
        command(c, user, $3)
      else
        msg(c, "Sorry, you are not an IRC operator.")
      end
    end
  end    
  
  def command(c, user, command)
    if command =~ /^eval (.*)$/i
      unless user.mode.include?("a")
        msg(c, "Sorry, you are not an IRC operator of sufficient rank.")
        return
      end
      begin
        result = eval($1)
        msg(c, "=> #{result.to_s}")
      rescue Exception => e
        msg(c, "!| #{e}")
        msg(c, "!| #{e.backtrace.join("\n")}")
      end
    elsif command =~ /^shutdown\s*$/i
      unless user.mode.include?("a")
        msg(c, "Sorry, you are not an IRC operator of sufficient rank.")
        return
      end
      send(":#{$protocol.sid} ENCAP * SNOTE s :Received shutdown from #{user.hostmask}. Exiting..")
      $log.fatal "Received @shutdown from #{user.hostmask}."
      RServ::Plugin.unload_all_and_quit()
    elsif command =~ /^uptime\s*$/i
      elapsed = Time.now.to_i - @starttime
      days = elapsed/86400
      hours = elapsed/3600
      msg(c, "Up #{days} days (#{hours} hours)")
    elsif command =~ /^load (\w+)\s*$/i
      begin
        RServ::Plugin.load($1)
        msg(c, "Plugin #{$1} loaded successfully.")
      rescue LoadError => e
        msg(c, "Error loading plugin #{$1}: #{e}")
      end
    elsif command =~ /^unload (\w+)\s*$/i
      begin
        RServ::Plugin.unload($1)
        msg(c, "Plugin #{$1} unloaded successfully.")
      rescue => e
        msg(c, "Error unloading plugin #{$1}: #{e}")
      end
    elsif command =~ /^reload (\w+)\s*$/i
      begin
        RServ::Plugin.unload($1)
        msg(c, "Plugin #{$1} unloaded successfully.")
        RServ::Plugin.load($1.downcase) #filenames should be lowercase
        msg(c, "Plugin #{$1} loaded successfully.")
      rescue => e
        msg(c, "Error reloading plugin #{$1}: #{e}")
      end
    elsif command =~ /^vhost (\S+) (\S+)\s*$/i
      send(":#{$protocol.sid} CHGHOST #{$1} #{$2}")
      msg(c, "Virtual host set on user. Please note this is not persistent.")
    elsif command =~ /^snote (.+)\s*$/i
      send(":#{$protocol.sid} ENCAP * SNOTE s :#{$1}")
    elsif command =~ /^join (#\S+)\s*$/i
      @control.join($1)
    elsif command =~ /^part (#\S+)\s*$/i
      @control.part($1)
    end
  end
  
  def msg(t, msg)
    @control.privmsg(t, msg)
  end
end
