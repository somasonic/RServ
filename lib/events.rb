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

module RServ

  # The RServ::Events class is used to communicate between
  # plugins, modules, core libs, and anything else in RServ.
  # It works by having an object "subscribe" to an event with
  # an object and method, and that'll be called when the event
  # is called.

  class Events
    def initialize
      @events = Array.new
    end

    # Add an event. Object can usually be self, method is a 
    # symbol, and name is the event name in the module::name
    # form. e.g. add(self, :on_myevent, "core::myevent").
    def add(object, method, name)
      @events.push [object, method, name.downcase]
    end

    # Removes all events that match the arguments.
    def del(object, method, name)
      @events.delete [object, method, name.downcase]
    end

    # Removes all events for obj.
    def unregister(obj)
      @events.delete_if {|e| e[0] == obj}
      $log.info "Unregistering object #{obj.to_s} (#{obj.class})."
    end

    # Sends an event. It's failsafe, and logs to the errorlog
    # if an error occurs when calling a method. 
    def send(event, *args)
      @events.each do |e|
        wants = e[2]
        if wants.downcase == event.downcase
          obj = e[0]
          meth = e[1]
          if obj.respond_to?(meth)
            begin
              $log.debug("Calling #{obj.method(meth)} for #{event}.")
              obj.method(meth).call(*args)
            rescue => boom
              $log.error("Failed to call #{obj}::#{meth} (with args: #{args.join(";")}) for #{event} #{boom.message}")
              $log.error(boom.backtrace.inspect.join("\r\n"))
              #del [obj, meth, wants] unless obj == $protocol # we don't want to stop responding to everything
              # this is the #1 cause of ping timeouts so I am removing this "feature"
            end
          end
        end
      end
      if event =~ /^cmd::(.*)$/
        cmd = $1
        plugins = Plugin.list
        clients = IRC::PsuedoClient.list
        
        objects = plugins + clients
          
        objects.each do |p|
          if p.respond_to?("cmd_#{cmd}")
            $log.debug("Calling #{p.method("cmd_#{cmd}")} for #{event}.")
            Thread.new { p.method("cmd_#{cmd}").call(*args) }
          end
        end
      end
    end
  end
end
