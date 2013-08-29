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

module RServ::IRC
  
  class PsuedoClient
    
    @@base_id = 1
    @@instances = Array.new
    
    attr_reader :nick, :user, :host, :modes, :uid, :gecos, :channels
    attr_accessor :whois_str
  
    def initialize(nick, user, host, gecos = "IRC Services", modes = "S", channels = Array.new)
      @@instances << self
      
      @nick = nick
      @user = user
      @host = host
      @modes = modes
      @gecos = gecos
      
      @whois_str = "is a Network Service"
      
      @channels = channels
      
      @uid = Configru.link.serverid + "SR" + ("%04d" % @@base_id)
      @@base_id += 1
      
      $event.add(self, :on_burst, "server::burst")
      $event.add(self, :join_channels, "server::connected")
      
      if $protocol.established
        on_burst
        join_channels
      end
    end
    
    def self.list
      @@instances
    end
    
    def to_s
      @nick
    end
    
    # irc methods
    
#   TODO nick changing 
#   def nick=(newnick)
#     @nick = newnick
#   end
    
    def join_channels(op = false)
      return if @channels.size == 0
      @channels.each do
        |channel|
        send(":#{@uid} JOIN #{Time.now.to_i} #{channel} +") 
        tmode(channel, "+o #{@uid}") if op
      end
    end
        
    def quit(msg = "Service shutting down..")
      send(":#{@uid} QUIT :#{msg}")
      @channels.each do
        |chan|
        $protocol.channels[chan].part(@uid)
      end
      $event.unregister(self)
      @@instances.delete(self)
    end
    
    def part(channel, msg = "Leaving channel..")
      send(":#{@uid} PART #{channel} :#{msg}")
    end
    
    def join(channel, op = true)
      send(":#{@uid} JOIN #{Time.now.to_i} #{channel} +") 
      tmode(channel, "+o #{@uid}") if op
      @channels << channel
      $protocol.channels[channel].join(@uid)
    end
    
    def privmsg(target, msg)
      send(":#{@uid} PRIVMSG #{target} :#{msg}")
    end
    
    def action(target, msg)
      send(":#{@uid} PRIVMSG #{target} :\x01ACTION #{msg}\x01")
    end
    
    def notice(target, msg)
      send(":#{@uid} NOTICE #{target} :#{msg}")
    end
    
    def encap(target, command)
      send(":#{@uid} ENCAP #{target} #{command}")
    end
    
    def kill(target, msg)
      send(":#{@uid} KILL #{target} :#{Configru.link.name} (#{msg})")
      $event.send("link::input", ":#{@uid} KILL #{target} :#{Configru.link.name} (#{msg})")
      $protocol.users.delete target if $protocol.users.has_key?(target)
    end
    
    def remove(chan, target, msg = "Goodbye")
      send(":#{@uid} REMOVE #{chan} #{target} :#{msg}")
      $event.send("link::input", ":#{@uid} KICK #{chan} #{target} :#{msg}")
    end
    
    def kick(chan, target, msg = "Goodbye")
      send(":#{@uid} KICK #{chan} #{target} :#{msg}")
    end
    
    def tmode(channel, modestr)
      send(":#{@uid} TMODE #{$protocol.channels[channel].ts} #{channel} #{modestr}")
    end
    
    # on_ and cmd_ methods
    
    def cmd_kill(c)
      if c.params[0] == @uid
        $log.info "PsuedoClient #{@nick} killed (#{$protocol.get_uid(c.origin)}). Reconnecting."
        on_burst
        join_channels
      end
    end
    
    def cmd_whois(c)
      return unless c.params[0].downcase == @nick.downcase
      $protocol.send_numeric(c.origin, 311, "#{@nick} #{@user} #{@host} * :#{@gecos}")
      $protocol.send_numeric(c.origin, 312, "#{@nick} #{Configru.link.name} :#{Configru.link.description}")
      $protocol.send_numeric(c.origin, 313, "#{@nick} :#{@whois_str}")
      $protocol.send_numeric(c.origin, 318, "#{@nick.downcase} :End of /WHOIS list")
    end

    def cmd_kick(c)
      return unless c.params[1] == @uid #don't rejoin unless it's us being kicked
      join(c.params[0])
    end
    
    def on_burst
      send(":#{Configru.link.serverid} UID #{@nick} 0 0 +#{@modes} #{@user} #{@host} 0 #{@uid} :#{@gecos}")
    end
    
    private
    
    def send(text)
      $protocol.send_raw(text)
    end
    
  end
end
