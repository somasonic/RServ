module RServ

  # RServ::Timer is first used for checking for ping responses, but
  # will serve for any application when a method needs to be called
  # as a loop or over a period.
  
  class Timer
    
    attr_reader :created, :runcount
    attr_accessor :interval
    
    def initialize(interval, only_once = false)
      
      # Runs a block after an interval, and can repeat it.
      # RServ::Timer.new(60) { # this will run every sixty seconds, after 60 seconds }
      # RServ::Timer.new(60, true) { # this will run once, after 60 seconds }
      
      @runcount = 0
      @created = Time.now
      @interval = interval
    
      Thread.new do
        sleep @interval # sleep for the interval before executing

        if only_once
          yield
          @runcount = 1
          return
        else
          loop do
            yield
            @runcount = @runcount + 1
            sleep @interval
          end     
        end
      end
    end
    
  end
  
end
      