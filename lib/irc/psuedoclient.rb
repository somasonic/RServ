#Copyright (C) 2013 Andrew Northall
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), 
#to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
#and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
#DEALINGS IN THE SOFTWARE.

module RServ::IRC
  
  class PsuedoClient
    
    @@base_id = 1
    
    attr_reader :nick, :user, :host, :modes, :uid, :gecos, :channels
  
    def initialize(nick, user, host, gecos, modes, channels = Array.new)
      @nick = nick
      @user = user
      @host = host
      @modes = modes
      @gecos = gecos
      
      @channels = channels
      
      @uid = Configru.link.serverid + "SR" + ("%04d" % @@base_id)
      @@base_id += 1
      
      $event.add(self, :on_kill, "user::kill")
      $event.add(self, :on_burst, "server::burst")
      $event.add(self, :on_kick, "user::kick")
      
      on_burst if $link.established
    end
    
    def to_s
      @nick
    end
        
    def on_kill(murderer, murdered)
      if murdered == @uid
        $log.info "PsuedoClient #{@nick} killed (#{$link.get_uid(murderer)}). Reconnecting."
        on_burst
        on_connect
      end
    end
    
    def on_kick(chan, uid, why)
      return unless uid == @uid #don't rejoin unless it's us being kicked
      send(":#{@uid} JOIN #{Time.now.to_i} #{chan} +")
    end
    
    def on_burst
      send(":#{Configru.link.serverid} UID #{@nick} 0 0 +#{@modes} #{@user} #{@host} 0 #{@uid} :#{@gecos}")
    end
        
    def quit(msg = "Service shutting down..")
      send(":#{@uid} QUIT :#{msg}")
      @channels.each do
        |chan|
        $link.channels[chan].part(@uid)
      end
    end
    
    def part(channel, msg = "Leaving channel..")
      send(":#{@uid} PART #{channel} :#{msg}")
    end
    
    def join(channel)
      send(":#{@uid} JOIN #{Time.now.to_i} #{channel} +") 
      @channels << channel
      $link.channels[channel].join(@uid)
    end
    
    def privmsg(target, msg)
      send(":#{@uid} PRIVMSG #{target} :#{msg}")
    end
    
    def notice(target, msg)
      send(":#{@uid} NOTICE #{target} :#{msg}")
    end
    
    
    private
    
    def send(args)
      $event.send("proto::out", *args)
    end
    
  end
end
