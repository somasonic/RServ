#
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
 
require 'json'

class Stats < RServ::Plugin
 
  def initialize
    @control = RServ::IRC::PsuedoClient.new("Stats", "stats", Configru.link.name, "Statistics Services", "S")
 
    begin
      @data = load("data/stats")
    rescue
      @data = Hash.new
      @data["channels"] = Array.new
      @data["ignore"] = Array.new
      save(@data, "data/stats")
    end

    @data.each {|k,v| v.default = 0 if k[0] == "#" }
    
    $event.add(self, :on_input, "link::input")
    $event.add(self, :on_burst, "server::connected")
 
    on_burst if $protocol.established        
  end
 
  def on_burst
    @data['channels'].each { |c| @control.join(c, false) }
  end
 
  def on_unload
    @control.quit
    save(@data, "data/stats")
  end
 
  def on_input(line)
    if line =~ /^:(\w{9}) PRIVMSG (#\S*) :(.*)$/i
      return unless @control.channels.include?($2)
      user = $protocol.get_uid($1)
      command($2, user, $3)
    elsif line =~ /^:(\w{9}) PRIVMSG (#{@control.nick}|#{@control.uid}) :(.*)$/i
      user = $protocol.get_uid($1)
      private_command(user, $3)
    end
  end
 
  private
  
  def command(channel, user, command)
    return unless @control.channels.include?(channel)
    if command =~ /^!top(\d+)\s*$/i
      num = $1.to_i
      num = 10 if num > 30
      print_stats(channel, user, num)
    else
      if user.account.nil?
        @data[channel][user.nick] += 1
      else
        @data[channel][user.account] += 1
      end
      Thread.new { save(@data, "data/stats") }
    end
  end
  
  def print_stats(channel, user, max_pos = 10)
    stats = @data[channel].sort_by {|k,v| v}.reverse
    notice(user, "Top users for #{channel}:")
    position = 1
    stats.each do
      |player, count|
      next if @data["ignore"].include?(player.downcase)
      notice(user, "##{position}: #{player} - #{count} lines")
      position += 1
      break if position > max_pos
    end
  end
  
  def private_command(user, command)
    return unless user.oper?
    if command =~ /^enable (#\S+)\s*$/i
      @data[$1] = Hash.new(0)
      @data["channels"] << $1
      @control.join($1, false)
      save(@data, "data/stats")
      msg(user, "Enabled #{$1}")
    elsif command =~ /^disable (#\S+)\s*$/i
      @data.delete($1)
      @data["channels"].delete($1)
      @control.part($1)
      save(@data, "data/stats")
      msg(user, "Disabled #{$1}")
    elsif command =~ /^ignore list\s*$/i
      msg(user, "Users ignored: #{@data["ignore"].join(", ")}.")
    elsif command =~ /^ignore (\S+)\s*$/i
      @data["ignore"] << $1.downcase
      msg(user, "Now ignoring nickname #{$1}")
      save(@data, "data/stats")
    elsif command =~ /^unignore (\S+)\s*$/i
      @data["ignore"].delete($1.downcase)
      msg(user, "#{$1} removed from ignore list")
      save(@data, "data/stats")
    end
  end
 
  def load(file)
    f = File.open(file, 'r')
    data = JSON.load(f)
    f.close
    data
  end
 
  def save(data, file)
    f = File.open(file, 'w')
    JSON.dump(data, f)
    f.flush
    f.close
  end
   
  def msg(t, msg)
    @control.privmsg(t, msg)
  end

  def notice(t, msg)
    @control.notice(t, msg)
  end
end
