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
    
    attr_reader :nick, :user, :host, :modes
    attr_accessor :base_id
    
    self.base_id = 0
    
    class << self
      attr_accessor :uid
    end
    
    def self.inherited(sub)
      super
      sub.uid = Configru.link.serverid + ("%03d" % self.base_id)
      self.base_id += 1
    end
  
    def initialize(nick, user, host, gecos, modes)
      @nick = nick
      @user = user
      @host = host
      @modes = modes
      @gecos = gecos
      
      $event.add(self, :on_kill, "user::kill")
      $event.add(self, :on_connect, "server::connected")
      $event.add(self, :on_whois, "user::whois")
    end
    
    def to_s
      @nick
    end
    
    def on_whois(arg1, arg2, arg3)
      #pass
    end
    
    def on_kill
      send(":#{Configru.link.serverid} UID #{@nick} 0 0 +#{@modes} #{@user} #{@host} 0 #{@uid} :#{@gecos}")
    end

    def on_connect
      send(":#{Configru.link.serverid} UID #{@nick} 0 0 +#{@modes} #{@user} #{@host} 0 #{@uid} :#{@gecos}")
    end
    
    private
    
    def send(args)
      $event.send("proto::out", *args)
    end
    
  end
end
