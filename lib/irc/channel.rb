module RServ::IRC
  
  class Channel
    attr_reader :name
    attr_accessor :ts, :mode, :users, :ops, :voiced
    
    def initialize(name, ts, mode, users)
      @name, @ts, @mode = name, ts, mode
      
      @users, @ops, @voiced = users
      eng_users = Array.new
      @users.map {|u| eng_users << $link.get_uid(u)}
      $log.info "New channel #{@name} with #{@users.size} users (#{@ops.size} ops and #{@voiced.size} voiced). Modes: #{@mode}. Userlist: #{eng_users.join(", ")}."
    end
    
    def to_s
      @name
    end
    
    def has_op?(user)
      @ops.include?(user)
    end
    
    def has_voice?(user)
      @voice.include?(user)
    end
    
    def part(user)
      @users.delete user
    end
    
    def join(user)
      @users << user
    end
    
    def voice(user)
      @voiced << user if @users.include?(user)
    end
    
    def devoice(user)
      @voiced.delete user
    end
    
    def deop(user)
      @ops.delete user
    end
    
    def op(user)
      @ops << user if @users.include?(user)
    end 
    
    def part(user)
      @users.delete user
      @voiced.delete user
      @ops.delete user
    end
    
  end
  
end