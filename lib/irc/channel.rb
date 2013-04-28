module RServ::IRC
  
  class Channel
    attr_reader :name
    attr_accessor :ts, :mode, :users, :ops, :voice
    
    def initialize(name, ts, mode, users, ops = Array.new, voice = Array.new)
      @name, @ts, @mode, @users, @ops, @voice = name, ts, mode, users, ops, voice
    end
    
    def to_s
      @name
    end
    
  end
  
end