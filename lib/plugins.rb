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

module RServ
  class Plugin
		
    @name == File.basename(__FILE__.split("/")[-1], '.rb')
    
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
				$log.error "Error loading plugin #{f}. Error: #{e}"
			end
		end


    def self.unload(c)
      klass = if c.kind_of? Class then c else @children.find { |e| e.name.downcase == c } end
      $event.send("plugin::unload", klass)
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
    
    private
    
    def send(*args)
      $event.send("proto::out", *args)
    end

    def nick(*args)
      @instances["nick"].make(*args)
    end

    def event(*args)
      $event.add(*args)
    end
  end
end
