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
      do_sync(reply_target)
    elsif command =~ /^pool (\w+)$/i
      @control.privmsg(reply_target, pool($1))
    elsif command =~ /^depool (\w+)$/i
      @control.privmsg(reply_target, depool($1))
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
    @data["servers"].each do
      |name, data|
      ipv6 = data[2]
      ipv6 = "no ipv6" if ipv6 == nil
      @control.privmsg(target, "#{name}: #{data[1]} / #{ipv6} (pooled: #{data[0].to_s})")
    end
  end
  
  def pool(name)
    name.downcase!
    @data["servers"][name][0] = true
    save(@data, 'data/dns')
    return "Server pooled successfully."
  end
  
  def do_sync(target)
    domain = DNSimple::Domain.find("interlinked.me")
    servers = @data["servers"]

    DNSimple::Record.all(domain).each do
      |record|
      if record.name == "irc" or record.name == "ipv4" or record.name == "ipv6"
        record.delete()
      end
    end
    
    servers.each do
      |name, data|
      pooled, ipv4, ipv6 = data
      next unless pooled 
      DNSimple::Record.create(domain, "irc", "A", ipv4, {:ttl => 60})
      DNSimple::Record.create(domain, "ipv4", "A", ipv4, {:ttl => 60})
      next if ipv6 == nil
      DNSimple::Record.create(domain, "irc", "AAAA", ipv6, {:ttl => 60})
      DNSimple::Record.create(domain, "ipv6", "AAAA", ipv6, {:ttl => 60})
    end
    @control.privmsg(target, "Sync completed without error.")
  end
  
  def depool(name)
    name.downcase!
    @data["servers"][name][0] = false
    save(@data, 'data/dns')
    return "Server depooled successfully."
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
