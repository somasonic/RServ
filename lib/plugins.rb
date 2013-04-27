#--
# I couldn't for the life of me figure out plugins, so I asked
# Aria to help me, and she presented me with this code. So, th
# anks go to her (http://dinhe.net/~aredridel/projects/ruby)
#++
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
