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
    # if an error occurs when calling a method. Uses threads.
    def send(event, *args)
      Thread.new do
        @events.each do |e|
          wants = e[2]
          if wants.downcase == event.downcase
            obj = e[0]
            meth = e[1]
            if obj.respond_to?(meth)
              begin
                $log.info("Calling #{obj.method(meth)} for #{event}.")
                Thread.new { obj.method(meth).call(*args) }
              rescue => boom
                $log.error("Failed to call #{obj}::#{meth} for an event:\r\n#{boom}")
                del [obj, meth, wants]
              end
            end
          end
        end
      end
      Thread.new do
        if event =~ /^cmd::(.*)$/
          cmd = $1
          plugins = Plugin.list
          plugins.each do |p|
            if p.respond_to?("cmd_#{cmd}")
              Thread.new { p.method("cmd_#{cmd}").call(*args) }
            end
          end
        end
      end
    end
  end
end
