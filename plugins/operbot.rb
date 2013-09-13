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
# not of much use to anyone

require 'openssl'
require 'timeout' 

class OperBot < RServ::Plugin
  def initialize
    @control = RServ::IRC::PsuedoClient.new("OperBot", "operbot", "rserv.interlinked.me", "IRC Operator Services", "oS", ["#opers", "#services"])
    @control.whois_str = "is an IRC operator service."

    server = TCPServer.new(61600)
    context = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.open("data/os.crt"))
    context.key = OpenSSL::PKey::RSA.new(File.open("data/os.key"))
    @server = OpenSSL::SSL::SSLServer.new(server, context)

    $log.info "OperSync notification listener listening on port 61600."
    
    begin
      @users = load('data/opersync-users')
    rescue
      @users = Hash.new
      save(@users, 'data/opersync-users')
    end
    
    Thread.new { main_os_loop() }

    $event.add(self, :on_input, "link::input")
  end

  def on_unload
    @control.quit
    @server.close
  end
  
  def on_input(line)
    line.chomp!
    if line =~ /^:(\w{9}) PRIVMSG #services :(.+)\s*$/i
      @control.privmsg("#opers", "#{BOLD}#{YELLOW}[HostServ]#{BOLD}#{COLOR} #{$2}") if $protocol.get_uid($1).nick == "HostServ"
      @control.privmsg("#opers", "#{BOLD}#{DARKRED}[OperServ]#{BOLD}#{COLOR} #{$2}") if $protocol.get_uid($1).nick == "OperServ"
      @control.privmsg("#opers", "#{BOLD}#{LIGHTCYAN}[HelpServ]#{BOLD}#{COLOR} #{$2}") if $protocol.get_uid($1).nick == "HelpServ"
      @control.privmsg("#opers", "#{BOLD}#{BLUE}[InfoServ]#{BOLD}#{COLOR} #{$2}") if $protocol.get_uid($1).nick == "InfoServ"
      @control.privmsg("#opers", "#{BOLD}#{GREEN}[Global]#{BOLD}#{COLOR} #{$2}") if $protocol.get_uid($1).nick == "Global"
    end
  end

  def cmd_kill(c)
    murdered = c.params[0]
    if c.origin.size < 9
      murderer = c.origin
    else
      murderer = $protocol.get_uid(c.origin).nick
    end
    reason = c.params[1]
    @control.privmsg("#opers", "#{BOLD}#{DARKRED}[KILL]#{BOLD}#{COLOR} [#{murdered.ip}] #{murdered.hostmask} killed by #{murderer}.")
  end

  private

  def main_os_loop
    loop do
      connection = @server.accept
      Thread.new do
        Timeout::timeout(5) do
          handle_connection(connection) 
        end
      end
      sleep 1
    end
  end

  def handle_connection(conn)
    authorised = false
    account = nil
    while (line = conn.gets)
      line = line.chomp
      if authorised
        if line =~ /^POSTDATA (.+)/i
          @control.privmsg("#opers", "#{BOLD}#{CYAN}[OperSync]#{BOLD}#{COLOR} #{account} SYNC #{$1}")
          conn.puts "OK"
          conn.close
          return
        end
      else
        if line =~ /^AUTHENTICATE (\S+) (\S+)\s*/i
          if @users[$1] == $2
            authorised = true
            account = $1
            conn.puts "OK"
          else
            conn.puts "ERROR: NOT AUTHENTICATED"
            conn.close
            return
          end
        end
      end
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
end
