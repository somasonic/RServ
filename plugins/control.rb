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
    host = Configru.control.host
    host = Configru.link.name if host == "link"
    @control = RServ::IRC::PsuedoClient.new(Configru.control.name, Configru.control.user, host, Configru.control.gecos, "SZ", Configru.channels.map {|c| "##{c}"})
    @prefix = Configru.control.prefix
    @starttime = Time.now.to_i
        
    $event.add(self, :on_input, "link::input")
  end
  
  def on_input(line)
    if line =~ /^:(\w{9}) PRIVMSG (#\S+) :#{@control.nick}\S{0,1} (.+)$/i
      return unless @control.channels.include?($2)
      c = $2
      user = $protocol.get_uid($1)
      command(c, user, $3) if user.oper?
    elsif line =~ /^:(\w{9}) PRIVMSG (#\S+) :#{@prefix}(.+)$/i
      return unless @control.channels.include?($2)
      c = $2
      user = $protocol.get_uid($1)
      command(c, user, $3) if user.oper?
    end
  end    
  
  def command(c, user, command)
    if command =~ /^eval (.*)$/i
      code = $1.strip
      Thread.new do
        begin
          result = eval(code)
          msg(c, "#{BOLD}#{GREEN}=>#{BOLD}#{COLOR} #{result.to_s}")
        rescue Exception => e
          msg(c, "#{BOLD}#{RED}!|#{BOLD}#{COLOR} #{e}")
          msg(c, "#{BOLD}#{RED}!|#{BOLD}#{COLOR} #{e.backtrace.join("\n")}")
        end
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
      rescue Exception => e
        msg(c, "Error loading plugin #{$1}: #{e}")
      end
    elsif command =~ /^unload (\w+)\s*$/i
      begin
        if RServ::Plugin.unload($1)
          msg(c, "Plugin #{$1} unloaded successfully.")
        else
          msg(c, "I know of no such plugin #{$1}.")
        end
      rescue => e
        msg(c, "Error unloading plugin #{$1}: #{e}")
      end
    elsif command =~ /^reload (\w+)\s*$/i
      begin
        unless RServ::Plugin.unload($1)
          msg(c, "I know of no such plugin #{$1}.")
          return
        end
        if $1 == self.class.to_s
          Thread.new do
            sleep 0.1
            @control.quit
            RServ::Plugin.load(self.class.to_s)
            send(":RServ PRIVMSG #{c} :Plugin #{self.class.to_s} reloaded successfully.")
          end
        else  
          RServ::Plugin.load($1)
          msg(c, "Plugin #{$1} reloaded successfully.")
        end
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
    elsif command =~ /^mode (#\S*) (.+)\s*$/i
      @control.tmode($1, $2)
    end
  end
  
  def msg(t, msg)
    @control.privmsg(t, msg)
  end
end
