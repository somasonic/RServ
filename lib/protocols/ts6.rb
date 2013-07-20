##
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

require 'lib/irc/command'
require 'lib/irc/user'
require 'lib/irc/server'
require 'lib/irc/channel'

module RServ::Protocols
	class TS6
    
		attr_reader :name, :sid, :established, :remote_sid
    attr_accessor :users, :channels, :servers
    
		def initialize
			@name = Configru.link.name
			@sid = Configru.link.serverid
      @link = nil #socket
      @established = false #whether the burst has ended
      @remote = nil # remote RServ::IRC::Server object
      
      @servers = Hash.new 
      @users = Hash.new
      @channels = Hash.new
            
			$event.add(self, :on_start, "link::start")
      $event.add(self, :on_input, "link::input")
      $event.add(self, :on_close, "link::close")
      $event.add(self, :on_output, "proto::out")
      
      $protocol = self
		end
    
    def get_uid(uid)
      @users[uid]
    end
    
    def get_sid(sid)
      @servers[sid]
    end
    
    def send_numeric(target, numeric, text)
      send(":#{@sid} #{numeric.to_s} #{target} #{text}")
    end
    
    def send_raw(text)
      send(text)
    end
    
		def on_start(link)
			@link = link
      $log.info "Connected to #{Configru.server.addr}, sending PASS, CAPAB and SERVER"
			send("PASS #{Configru.link.sendpassword} TS 6 :#{Configru.link.serverid}") # PASS password TS ts-ver SID
			send("CAPAB :QS ENCAP SAVE RSFNC SERVICES REMOVE") # Services to identify as a service
			send("SERVER #{Configru.link.name} 0 :#{Configru.link.description}")              
    end
      		
		def on_output(line)
			send(line)
		end
		
		def on_close(link)
      $log.info "Link closed."
      $log.info "Restarting in #{Configru.server.reconnectdelay} seconds..."
      sleep Configru.server.reconnectdelay
      exec('/usr/bin/env', 'ruby', File.expand_path("../../../rserv.rb", __FILE__)) # just re-execute and quit, no cleanup necessary.
      exit
    end

		def on_input(line)
			line.chomp!
      sid = Configru.link.serverid
      name = Configru.link.name
			$log.debug("<---| #{line}")
      if @established
        
        if line =~ /^:[0-9A-Z]{9}/
          user_input(line)
        elsif line =~ /^:[0-9A-Z]{3}/
          server_input(line)
        elsif line =~ /^PING :.*$/
          send(":#{sid} PONG #{name} :#{@remote_sid}")
        elsif line =~ /^SQUIT (\w{3}) :(.*)$/
          $log.info "SQUIT received #{$1} (#{$2})"
          handle_squit($1)
        end
  
      else
        
        #establishing the link
        if line =~ /^:[0-9A-Z]{9}/
          user_input(line) #this isn't burst specific
          
        elsif line =~ /^PASS (\S+) TS 6 :(\w{3})$/ 
          @remote_sid = $2
  
          if Configru.link.recvpassword == $1
            $log.info "Password received and matched."
          else
            $log.fatal "Received incorrect link password from upstream SID #{$2}. Exiting."
            exit
          end
          
        elsif line =~ /^PING :(\S+)$/  
          if @remote_sid == nil
            $log.fatal "Received PING but have got no SID recorded. Exiting."
            exit
          end
          
          send("SVINFO 6 6 0 :#{Time.now.to_i}")
          send("PING :#{sid}") # ping upstream

          @servers.each do  #pong each server
            |remotesid, obj|
            send(":#{sid} PONG #{name} :#{remotesid}")
          end
                            
        elsif line =~ /^SERVER (\S+) 1 :(.*)$/
          server = RServ::IRC::Server.new(@remote_sid, $1, 1, $2)
          @remote = server
          @servers[@remote_sid] = server
          $log.info "Got SERVER from upstream #{@remote} (#{@remote.sid}) [#{@remote.hostname}]"
          $event.send("server::burst")
          
        elsif line =~ /^:(\w{3}) PONG (\S+) :(\w{3})$/
          if $1 == @remote_sid and $3 == sid # from our upstream only
            @established = true
            $event.send("server::connected")
            $log.info "Server connection established to #{$2} (#{$1})!"
          end
          
        elsif line =~ /^:(\w{3}) UID (\S+) (\d{1,2}) (\d{10}) \+([a-zA-Z]*) (\S+) (\S+) (\S+) ([0-9]\w{2}[A-Z][A-Z0-9]{5}) :(.*)$/
          user = RServ::IRC::User.new($2, $9, $3, $5, $6, $7, $8, $10)
          @users[user.uid] = user
          $log.info "New user #{user.uid} on #{user.sid}. Host: #{user.nick}!#{user.username}@#{user.hostname} (#{user.ip}) | Modes: +#{user.mode}"
          
        elsif line =~ /^:(\w{3}) SID (\S+) (\d{1,2}) ([0-9][0-9A-Z]{2}) :(.*)$/
          server = RServ::IRC::Server.new($4, $2, $3, $5)
          $log.info "New server: #{server.hostname} (#{server.sid}) [#{server.gecos}]"
          @servers[server.sid] = server
          
        elsif line =~ /^:([0-9]{1}[A-Z0-9]{2}) SJOIN (\d+) (#.*) (\+.*) :(.*)$/
          if @channels.has_key?($3)
            users, ops, voiced = parse_users($5)
            
            users.each {|u| @channels[$3].join(u) }
            ops.each {|o| @channels[$3].op(o) }
            voiced.each {|v| @channels[$3].voice(v) }
            
            eng_users = Array.new
            users.each {|u| eng_users << @users[u].nick }
            
            $log.info "SJOIN of #{users.size} users to #{$3} (#{ops.size} ops and #{voiced.size} voiced).  New users: #{eng_users.join(", ")}."  
            if $2.to_i < @channels[$3].ts
              @channels[$3].ts = $2.to_i
              @channels[$3].mode = $4
              $log.info "New TS for #{$3}: #{$2.ts}. New modes: #{$4}."
            end
          else
            chan = RServ::IRC::Channel.new($3, $2.to_i, $4, parse_users($5))
            @channels[chan.name] = chan
          end
        end
      end
    end

    private

		def send(text)
			$log.debug("--->| #{text}")
			@link.send(text) if @link
		end

    def user_input(line)
      sid = Configru.link.serverid
      name = Configru.link.name
      
      if line =~ /^:(\w{9}) AWAY$/
        $event.send("user::away", @users[$1])
        $log.info "User #{$1} (#{@users[$1]}) is no longer away."
        @users[$1].away = false
        
      elsif line =~ /^:(\w{9}) AWAY :(.*)$/
        $log.info "User #{$1} (#{@users[$1].nick}) is away (#{$2})."
        @users[$1].away = true      
        $event.send("user::unaway", @users[$1])
        
      elsif line =~ /^:(\w{9}) NICK (\S+) :(\d+)$/
        $log.info "Nick change for #{$1}: #{@users[$1]} -> #{$2}"
        
        old_nick = @users[$1]
        @users[$1].nick = $2
        RServ::IRC::Command.new("nick", [$2], $1)
      
      elsif line =~ /^:(\w{9}) QUIT :(.*)$/
        $log.info "User #{@users[$1].nick} quit (#{$2})."
        olduser = @users[$1]
        @users.delete $1
        
        # remove user from any channels they were in
        @channels.each do
          |name, chan|
          chan.part($1)
        end
        RServ::IRC::Command.new("quit", [olduser], $2)
        
      elsif line =~ /^:(\w{9}) ENCAP \S{1,3} REALHOST (.*)$/
        @users[$1].realhost = $2
        $log.debug "Realhost for #{$1} (#{@users[$1]}) is #{@users[$1].realhost}."
        $event.send("user::realhost", @users[$1], $2)
        
      elsif line =~ /^:(\w{9}) ENCAP \S{1,3} LOGIN (.*)$/
        @users[$1].account = $2
        $event.send("user::login", @users[$1])
        $log.info "#{@users[$1]} logged in as #{@users[$1].account}."
        
      elsif line =~ /^:(\w{9}) ENCAP \S{1,3} CERTFP :(.*)$/
        @users[$1].certfp = $2
        $log.info "Certificate fingerprint for #{@users[$1]}: #{$2}"
        $event.send("user::certfp", @users[$1], $2)
                
      elsif line =~ /^:(\w{9}) JOIN (\d+) (#.*) (\+.*)$/
        chan = @channels[$3]
        chan.join($3)
        
        if $2.to_i < chan.ts
          chan.ts = $2.to_i
          chan.mode = $4
          $log.info "New TS for #{chan}: #{chan.ts}. New modes: #{chan.mode}."
        end

        RServ::IRC::Command.new("join", [$3], $1)
        $log.info("#{@users[$1]} joined #{chan}.")
        @channels[$3] = chan 
        
      elsif line =~ /^:(\w{9}) KICK (#.*) (\w{9}) :(.*)$/
        #check if it is relevant
        if $3[0..2] == Configru.link.serverid
          RServ::IRC::Command.new("kick", [$2, $3, $4], $1)
          $log.info("#{$3} kicked from #{$2} by #{@users[$1].nick} (#{$4}). Rejoining...")
        else
          chan = @channels[$2]
          chan.part($3)
        
          if chan.users.size > 0
            @channels[$2] = chan
          else
            @channels.delete($2)
          end
          RServ::IRC::Command.new("kick", [$2, $3, $4], $1)
        end
        
      elsif line =~ /^:(\w{9}) TOPIC (#.*) :(.*)$/
        @channels[$2].topic = $3
        $log.info("New topic for #{@channels[$2]} set by #{@users[$1]}: #{$3}")
        
      elsif line =~ /^:(\w{9}) PART (#\S*)/
        chan = @channels[$2]
        chan.part($1)
        $log.info("#{@users[$1]} parted #{chan}.")
        
        if chan.users.size > 0
          @channels[$2] = chan
        else
          @channels.delete($2)
        end
        RServ::IRC::Command.new("part", [$2], $1)
        
      elsif line =~ /^:(\w{9}) KILL (\w{9}) :(.*)$/
        RServ::IRC::Command.new("kill", [$2, $3], $1)
        
      elsif line =~ /^:(\w{9}) MODE (\w{9}) :(.*)$/
        @users[$2].do_mode($3)
        RServ::IRC::Command.new("mode", [$2, $3], $1)
        
      elsif line =~ /^:(\w{9}) WHOIS (\S+) :(\S+)$/
        RServ::IRC::Command.new("whois", [$3], $1)
        
      end
      
    end
  
    def server_input(line)
      sid = Configru.link.serverid
      name = Configru.link.name
      
      if line =~ /^:(\w{3}) UID (\S+) (\d{1,2}) (\d{10}) \+([a-zA-Z]*) (\S+) (\S+) (\S+) ([0-9]\w{2}[A-Z][A-Z0-9]{5}) :(.*)$/
        user = RServ::IRC::User.new($2, $9, $3, $5, $6, $7, $8, $10)
        @users[user.uid] = user
        $event.send("user::connected", @users[$9])
        $log.info "New user #{user.uid} on #{user.sid} (#{@servers[$1].hostname}). Host: #{user.nick}!#{user.username}@#{user.hostname} (#{user.ip}) | Modes: +#{user.mode}."
  
      elsif line =~ /^:(\w{3}) SID (\S+) (\d{1,2}) ([0-9][0-9A-Z]{2}) :(.*)$/
        server = RServ::IRC::Server.new($4, $2, $3, $5)
        $log.info "New server: #{server.hostname} (#{server.sid}) [#{server.gecos}]."
        @servers[server.sid] = server
        $event.send("server::sid", server)
        send(":#{sid} PING #{name} :#{server.sid}")
     
      elsif line =~ /^:(\w{3}) SJOIN (\d+) (#.*) (\+.*) :(.*)$/
        if @channels.has_key?($3)
          users, ops, voiced = parse_users($5)
          
          users.each {|u| @channels[$3].join(u) }
          ops.each {|o| @channels[$3].op(o) }
          voiced.each {|v| @channels[$3].voice(v) }
          
          eng_users = Array.new
          users.each {|u| eng_users << @users[u].nick }
          
          $log.info "SJOIN to #{$3} (#{users.size} ops and #{voiced.size} voiced).  New users: #{eng_users.join(", ")}."  
          if $2.to_i < @channels[$3].ts
            @channels[$3].ts = $2.to_i
            @channels[$3].mode = $4
            $log.info "New TS for #{$3}: #{$2}. New modes: #{$4}."
          end
        else
          chan = RServ::IRC::Channel.new($3, $2.to_i, $4, parse_users($5))
          @channels[chan.name] = chan
        end
        
      elsif line =~ /^:(\w{3}) ENCAP \S{1,3} SU (\w{9}) :(\w+)$/
        @users[$2].account = $3
        $log.info "#{@users[$2]} logged in as #{$3}"
        
      elsif line =~ /^:(\w{3}) ENCAP \S{1,3} CHGHOST (\w{9}) :(.*)$/
        @users[$2].hostname = $3
        $log.info "New host for #{@users[$2]}: #{$3}"
     
      elsif line =~ /^:(\w{3}) PING (\S+) :(.*)$/
        #this is only called when a remote server pings (i.e. not from the server we connect to)
        send(":#{sid} PONG #{name} :#{$1}")        
      end
      
    end
    
    def handle_squit(sid)
      if sid == Configru.link.serverid
        $log.fatal "SQUIT received for our SID."
        return
      end
      
      $event.send("server::squit", @servers[sid])
      
      @servers.delete(sid)
      users = @users.select {|uid,user| user.sid == sid}
      users.each do
        |uid, user|
        $event.send("user::quit", user, "*.net *.split")
        @users.delete uid
        
        # remove user from any channels they were in
        @channels.each do
          |name, chan|
          chan.part(uid)
        end
      end
    end 
      
    def parse_users(user_str)
      raw_users = user_str.split(" ")
      
      users = Array.new
      ops = Array.new
      voiced = Array.new
      
      raw_users.each do
        |user|
        if user =~ /^@\+(.*)$/
          ops << $1
          voiced << $1
          users << $1
        elsif user =~ /^\+(.*)$/
          voiced << $1
          users << $1
        elsif user =~ /^@(.*)$/
          ops << $1
          users << $1
        else
          users << user
        end
      end
      
      return [users, ops, voiced]
    end
    
	end
end

RServ::Protocols::TS6.new
