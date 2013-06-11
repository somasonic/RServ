#Copyright (C) 2013 Andrew Northall
#Copyright (C) 2013 Aria Stewart
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

module RServ
  class Plugin
		
    @name = File.basename(__FILE__.split("/")[-1], '.rb')
    
    attr_accessor :clients, :name
    
    def initialize
      @clients = Array.new
    end
    
    def self.inherited(child)
      @children ||= []
      @instances ||= {}
      @children << child
      @instances[child] = child.new
    end

    def self.load(f)
      begin
        $log.info "Attempting to load plugin #{f}."
        Kernel.load(f)
        fn = File.basename(f, '.rb')
        klass = @children.find { |e| e.name.downcase == fn }
        @instances[klass] = klass.new if klass
        $log.info "Loaded plugin #{f}."
      rescue => e
        $log.error "Error loading plugin #{f}. Error: #{e}\n#{e.backtrace.join("\n")}"
      end
    end


    def self.unload(c)
      klass = nil
      if c.kind_of? Class 
        klass = c
      else 
        klass = @children.find { |e| e.name.downcase == c }
      end
      klass.on_unload if klass.respond_to?("on_unload")
      $event.unregister(klass)
      Object.send :remove_const, klass.name.intern
      @children.delete klass
      @instances.delete klass
    end

    def self.list
      a = Array.new
      @instances.each_value {|x| a.push x}
      a
    end
    
    def on_unload
      @clients.each {|c| c.quit("Service unloaded") }
    end
    
    private
    
    def send(*args)
      $event.send("proto::out", *args)
    end
    
    def event(*args)
      $event.add(*args)
    end  

    def new_psuedoclient(*args)
      new_c = RServ::IRC::PsuedoClient.new(*args)
      @clients = Array.new unless @clients
      @clients << new_c
      new_c
    end
    
  end
end
