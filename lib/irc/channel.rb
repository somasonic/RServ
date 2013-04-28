module RServ::IRC
  
  class Channel
    attr_reader :name
    attr_accessor :ts, :mode, :users, :ops, :voiced
    
    def initialize(name, ts, mode, users)
      @name, @ts, @mode = name, ts, mode
      
      @users, @ops, @voiced = parse_users(users)
      
      $log.info "New channel with #{@users.size} users (#{@ops.size} ops and #{@voiced.size} voiced). Userlist: #{@users.join(" ,")}."
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
    
    private
        
    def parse_users(user_str)
      raw_users = user_str.split(" ")
      
      users = Array.new
      ops = Array.new
      voiced = Array.new
      
      raw_users.each do
        |user|
        first_bit = user[0]
        second_bit = user[1]
        clean_user = user.gsub(/[\@\+]/, '')
        users << clean_user
        if first_bit == "@" or second_bit == "@"
          ops << clean_user
          $log.info "#{$link.get_uid(clean_user)} has op on #{@name}."
        elsif first_bit == "+" or second_bit == "+"
          voiced << clean_user
          $log.info "#{$link.get_uid(clean_user)} has voice on #{@name}."
        end
      end
      
      return [users, ops, voiced]
    end
  end
  
end