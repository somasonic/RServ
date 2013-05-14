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

require 'lib/irc/psuedoclient'

class Control < RServ::Plugin
  def initialize
    @control = RServ::IRC::PsuedoClient.new("RServ", "rserv", "rserv.interlinked.me", "Ruby Services", "Zo")
  end  
  
  def cmd_privmsg(cmd)
    target = cmd.params.split(" ")[0]
    message = cmd.params.sub(/^\w+ :(.*)$/, '\1')
    
    if $link.users[cmd.uid].host == "bnc-im/admin/andy"
      if target == "#opers" or target == "RServ"
        command = message.split(" ")[0..1].join(" ")
        if command == "RServ: eval"
          params = message.split(" ")[2..-1].join(" ")
          @control.privmsg(target, "Evaling ruby code...")
          begin
            result = exec(params)
          rescue => e
            result = e
          end
          @control.privmsg(target, "Result: #{result}")
        end
      end
    end
  end
end
