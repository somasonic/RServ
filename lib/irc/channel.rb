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
  
  class Channel
    attr_reader :name
    attr_accessor :ts, :mode, :users, :ops, :voiced, :topic
    
    def initialize(name, ts, mode, users)
      @name, @ts, @mode = name, ts, mode
      
      @users, @ops, @voiced = users

      @topic = nil
      
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
      @voiced.include?(user)
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
