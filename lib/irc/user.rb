module RServ::IRC
  
  class User
    
    attr_reader :sid, :uid, :hops, :away, :away_reason
    attr_accessor :nick, :mode, :username, :hostname, :ip, :gecos, :account, :realhost
  
    def initialize(nick, uid, hops, mode, username, hostname, ip, gecos)
      @nick, @uid, @hops, @mode = nick, uid, hops, mode
      @username, @hostname, @ip, @gecos = username, hostname, ip, gecos
      
      @account, @realhost = nil, nil
      
      @away = false 
      
      @sid = uid[0..2]
    end
    
    def to_s
      @nick
    end
    
    def hostmask
      "#{@nick}!#{@username}@#{@hostname}"
    end
    
    def away=(away = true)
      raise TypeError, 'Away status must be boolean' unless away == true or away == false
      @away = away
    end
    
  end
  
end