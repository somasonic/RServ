##
# Copyright (C) 2013 Andrew Northall
# Copyright (C) 2008 Aria Stewart
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

require 'lib/irc/psuedoclient'

module RServ
  class Plugin
		    
    attr_accessor :name
    
    def initialize
      @name = File.basename(__FILE__.split("/")[-1], '.rb')
    end
    
    def self.inherited(child)
      @children ||= []
      @instances ||= {}
      @children << child
    end

    def self.load(f)
      begin
        f = "plugins/#{f.downcase}.rb" unless f =~ /\.rb$/
        $log.info "Attempting to load plugin #{f}."
        Kernel.load(f)
        fn = File.basename(f, '.rb')
        klass = @children.find { |e| e.name.downcase == fn }
        @instances[klass.to_s] = klass.new
        @instances[klass.to_s].on_connect if $protocol.established and @instances[klass.to_s].respond_to?("on_connect")
        $log.info "Loaded plugin #{f}."
      rescue => e
        $log.error "Error loading plugin #{f}. Error: #{e}\n#{e.backtrace.join("\n")}"
        raise LoadError
      end
    end
    
    def self.unload(c)      
      if @instances.has_key?(c)
        klass = @instances[c]
      else
        return
      end
      klass.on_unload if klass.respond_to?("on_unload")
      $event.unregister(klass)
      @children.delete_if {|name| name.to_s == klass.class.to_s}
      @instances.delete klass.class.to_s
      Object.send :remove_const, klass.class.to_s
    end

    def self.list
      a = Array.new
      @instances.each_value {|x| a.push x}
      a
    end
    
    private
    
    def send(*args)
      $event.send("proto::out", *args)
    end
  end
end
