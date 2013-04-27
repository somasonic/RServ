module RServ::IRC
  
  class User
    
    attr_reader :sid, :uid, :hops
    attr_accessor :nick, :mode, :username, :hostname, :ip, :gecos, :account, :realhost, :away
  
    def initialize(nick, uid, hops, mode, username, hostname, ip, gecos)
      @nick, @uid, @hops, @mode = nick, uid, hops, mode
      @username, @hostname, @ip, @gecos = username, hostname, ip, gecos
      
      @account, @realhost = nil, nil
      
      @away = false 
      
      @sid = uid[0..2]
    end
    
  end
  
end