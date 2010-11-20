module RServ
  
  # Command class. Has three attributes:
  #   * command => the command (e.g. privmsg)
  #   * prefix => bit before (e.g. a hostmask)
  #   * params => bits after in an array
  class Command
    attr_reader :command, :prefix, :params
    alias :to_s :command
    def initialize(command, params, prefix = nil)
      @command = command.downcase
      @prefix = prefix.downcase
      @params = params
    end
  end
end
