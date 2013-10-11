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
# network specific plugin for interlinked
# not of much use to anyone

require 'dnsimple'

class DNSServ < RServ::Plugin
  def initialize
    @control = RServ::IRC::PsuedoClient.new("DNSServ", "dnsserv", "rserv.interlinked.me", "DNS Services", "S", ["#opers", "#services"])
    
    begin
      @data = load('data/dns')
    rescue
      @data = Hash.new
      @data["username"] = "insert-here"
      @data["password"] = "insert-here"
      @data["servers"] = Hash.new
      save(@data, 'data/dns')
    end

    DNSimple::Client.username   = @data["username"]
    DNSimple::Client.password   = @data["password"]
    DNSimple::Client.http_proxy = {}

    $event.add(self, :on_input, "link::input")
  end

  def on_unload
    @control.quit
    save(@data, 'data/dns')
  end
  
  def on_input(line)
    line.chomp!
    if line =~ /^:(\w{9}) PRIVMSG #opers :(DNSServ:?,? |!)(.+)\s*$/i
      user = $protocol.get_uid($1)
      return unless user.oper?
      dns_cmd(user, "#opers", $3)
    elsif line =~ /^:(\w{9}) PRIVMSG #{@control.uid} :!?(.+)\s*$/i
      user = $protocol.get_uid($1)
      return unless user.oper?
      dns_cmd(user, $1, $2)
    end
  end

  private
  
  def dns_cmd(user, reply_target, command)
    if command =~ /^server add (\w+) (\d+\.\d+\.\d+\.\d+)$/i
      @control.privmsg(reply_target, add_server($1, $2))
    elsif command =~ /^server add (\w+) (\d+\.\d+\.\d+\.\d+) (\S+)$/i
      @control.privmsg(reply_target, add_server($1, $2, $3))
    elsif command =~ /^server (del|delete|rem|remove) (\w+)$/i
      @control.privmsg(reply_target, del_server($2))
    elsif command =~ /^status$/i
      print_status(reply_target)
    elsif command =~ /^sync$/i
      Thread.new { do_sync(reply_target) }
    elsif command =~ /^pool (.+)\s*$/i
      $1.strip.spilt(" ").each { |s| @control.privmsg(reply_target, pool(s)) }
    elsif command =~ /^depool (.+)\s*$/i
      $1.strip.spilt(" ").each { |s| @control.privmsg(reply_target, depool(s)) }
    end
  end
  
  def add_server(name, ipv4, ipv6 = nil)
    name.downcase!
    if @data["servers"].has_key?(name)
      return "Error: server already exists."
    end
    @data["servers"][name] = [false, ipv4, ipv6]
    save(@data, 'data/dns')
    return "Server #{name} added successfully."
  end
  
  def del_server(name)
    name.downcase!
    if @data["servers"].has_key?(name)
      @data["servers"].delete(name)
      save(@data, 'data/dns')
      return "#{name} has been deleted."
    else
      return "Error: #{name} does not exist."
    end
  end
  
   def print_status(target)
    @control.privmsg(target, "#{BOLD} Server".ljust(16) + "Pooled".ljust(9) + "IPv4".ljust(19) + "IPv6".ljust(40) + "Users")
    totalusers = 0
    @data["servers"].each do
      |name, data|
      users = 0
      server = $protocol.servers.select {|k,v| v.shortname == name}.values[0]
      $protocol.users.each {|k,v| users += 1 if k[0..2] == server.sid} unless server.nil?
      totalusers += users
      pooledstr = "#{GREEN}yes#{COLOR}\x0f" if data[0]
      pooledstr = "#{RED}no#{COLOR}\x0f" unless data[0]
      @control.privmsg(target, " " + name.ljust(14) + pooledstr.ljust(14) + data[1].ljust(19) + data[2].to_s.ljust(40) + users.to_s)
    end
    @control.privmsg(target, " #{BOLD}Total".ljust(84) + totalusers.to_s)
  end
 
  def pool(name)
    name.downcase!
    @data["servers"][name][0] = true
    save(@data, 'data/dns')
    return "Server #{name} pooled successfully."
  end
  
  def do_sync(target)
    servers = @data["servers"]
    one_pooled = false
    servers.each {|k,v| one_pooled = true if v[0] == true}
    unless one_pooled
      @control.privmsg(target, "Error: you cannot sync with no servers pooled.")
      return
    end
    @control.privmsg(target, "Syncing..")
   
    domain = DNSimple::Domain.find("interlinked.me")
    
    kept = Array.new
    DNSimple::Record.all(domain).each do
      |record|
      if record.name == "irc" or record.name == "ipv4" or record.name == "ipv6"
        keep = false
        servers.each do
          |key, server|
          pooled, ipv4, ipv6 = server
          if pooled
            if record.content == ipv4 or record.content == ipv6
              keep = true
              kept << record.content
            end
          end
        end
        record.delete() unless keep
      end
    end
    
    servers.each do
      |name, data|
      pooled, ipv4, ipv6 = data
      next unless pooled
      next if kept.include?(ipv4)
      DNSimple::Record.create(domain, "irc", "A", ipv4, {:ttl => 60})
      DNSimple::Record.create(domain, "ipv4", "A", ipv4, {:ttl => 60})
      next if ipv6 == nil
      next if kept.include?(ipv6)
      DNSimple::Record.create(domain, "irc", "AAAA", ipv6, {:ttl => 60})
      DNSimple::Record.create(domain, "ipv6", "AAAA", ipv6, {:ttl => 60})
    end
    @control.privmsg(target, "Sync completed without error.")
  end
  
  def depool(name)
    name.downcase!
    @data["servers"][name][0] = false
    save(@data, 'data/dns')
    return "Server #{name} depooled successfully."
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
end
