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
  
  class User
    
    attr_reader :sid, :uid, :hops, :away, :away_reason
    attr_accessor :nick, :mode, :username, :hostname, :ip, :gecos, :account, :realhost, :certfp, :ts
  
    def initialize(nick, uid, hops, mode, username, hostname, ip, gecos, ts)
      @nick, @uid, @hops, @mode = nick, uid, hops, mode
      @username, @hostname, @ip, @gecos = username, hostname, ip, gecos
      @ts = ts

      @account, @realhost = nil, hostname
      
      @away = false 
      
      @certfp = nil
      
      @sid = uid[0..2]
    end
    
    def to_s
      @nick
    end
    
    def oper?
      @mode.include?("o")
    end
    
    def hostmask
      "#{@nick}!#{@username}@#{@realhost}"
    end

    def pub_hostmask
      "#{@nick}!#{@username}@#{@hostname}"
    end
 
    def away=(away = true)
      raise TypeError, 'Away status must be boolean' unless away == true or away == false
      @away = away
    end
    
    def do_mode(changestr)
      splitmode = @mode.split("")
      if changestr =~ /\+([a-zA-Z]+)/
        plus_split = $1.split("")
        plus_split.each {|m| splitmode << m}
      end
      
      if changestr =~ /-([a-zA-Z]+)/
        minus_split = $1.split("")
        minus_split.each {|m| splitmode.delete(m) }
      end
      
      @mode = splitmode.join("")
      $log.info "Mode for #{@nick}: #{changestr}. New modes: #{@mode}"
    end
    
  end
  
end
