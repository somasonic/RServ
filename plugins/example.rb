class Example < RServ::Plugin
  def initialize
    $event.add(self, :on_start, "server::connected")
  end
  
  def on_start
    # code here will be executed upon link establishment
    # use send() to send raw text to the protocol
  end
  
  def on_input(raw_input)
    #
    # raw socket input
    #
  end
end
