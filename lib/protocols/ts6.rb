require 'lib/command'

require 'lib/irc/user'
require 'lib/irc/server'

module RServ::Protocols
	class TS6
		attr_reader :name, :established, :remote_sid
		def initialize
			@name = String.new
			@link = nil #socket
      @established = false
      @remote_sid = nil
      @remote = nil
      
      @servers = Hash.new
      @users = Hash.new
            
			$event.add(self, :on_start, "link::start")
      $event.add(self, :on_input, "link::input")
      $event.add(self, :on_close, "link::close")
      $event.add(self, :on_output, "proto::out")
		end
    
    def get_uid(uid)
      @users[uid]
    end
    
    def get_sid(sid)
      @servers[sid]
    end

		def on_start(link)
			@link = link
      sleep 1
      $log.info "Connected to #{Configru.server.addr}, sending PASS, CAPAB and SERVER"
			send("PASS #{Configru.link.sendpassword} TS 6 :#{Configru.link.serverid}") # PASS password TS ts-ver SID
			send("CAPAB :QS ENCAP SAVE RSFNC SERVICES") # Services to identify as a service
			send("SERVER #{Configru.link.name} 0 :#{Configru.link.description}")              
    end
      		
		def on_output(line)
			send(line)
		end
		
		def on_close(link)
      $log.info "Link closed."
      $log.info "Restarting..."
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
          $log.info "Ponging #{$1}"
        elsif line =~ /^SQUIT (\w{3}) :(.*)$/
          $log.info "SQUIT received for our SID: SQUIT #{$1} (#{$2})"
        end
  
      else
        
        #establishing the link
        if line =~ /^:[0-9A-Z]{9}/
          user_input(line)
        elsif line =~ /^PASS (\S+) TS 6 :(\w{3})$/ # todo: make match accept password to config
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
          # send SVINFO and introduce RServ bot
          send("SVINFO 6 6 0 :#{Time.now.to_i}")
          send(":#{sid} UID RServ 0 0 +Zo rserv rserv.interlinked.me 127.0.0.1 #{sid}SRV000 :Ruby Services")
          Configru.channels.each do # join channels 
            |chan|
            send(":#{sid} SJOIN #{Time.now.to_i} ##{chan} +nt :#{sid}SRV000")
          end
          send("PING :#{sid}") # ping upstream

          @servers.each do  #pong each server
            |remotesid, obj|
            send(":#{sid} PONG #{name} :#{remotesid}")
          end
          
          Configru.channels.each do # op ourselves
            |chan|
            send(":#{sid} TMODE 1 ##{chan} +o RServ")
          end          
        elsif line =~ /^SERVER (\S+) 0 :(.*)$/
          server = RServ::IRC::Server.new(@remote_sid, $1, 0, $2)
          @remote = server
          @servers[@remote_sid] = server
          $log.info "Got SERVER from upstream #{@remote} (#{@remote.sid}) [#{@remote.hostname}]"
        elsif line =~ /^:(\w{3}) PONG (\S+\.\w+) :(\w{3})$/
          if $1 == @remote_sid and $3 == sid # from our upstream only
            @established = true
            $event.send("server::connected")
            $log.info "Server connection established to #{$2} (#{$1})!"
          end
        elsif line =~ /^:(\w{3}) UID (\S+) (\d{1,2}) (\d{10}) \+([a-zA-Z]*) (\S+) (\S+) (\S+) ([0-9]\w{2}[A-Z][A-Z0-9]{5}) :(.*)$/
          #uid
          user = RServ::IRC::User.new($2, $9, $3, $5, $6, $7, $8, $10)
          @users[user.uid] = user
          $log.info "New user #{user.uid} on #{user.sid}. Host: #{user.nick}!#{user.username}@#{user.hostname} (#{user.ip}) | Modes: +#{user.mode}"
        elsif line =~ /^:(\w{3}) SID (\S+) (\d{1,2}) ([0-9][0-9A-Z]{2}) :(.*)$/
          server = RServ::IRC::Server.new($4, $2, $3, $5)
          $log.info "New server: #{server.hostname} (#{server.sid}) [#{server.gecos}]"
          @servers[server.sid] = server
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
        $log.debug "#{$1} AWAY: #{@users[$1].away}"
        $log.info "User #{$1} (#{@users[$1]}) is no longer away."
        @users[$1].away = false
      elsif line =~ /^:(\w{9}) AWAY :(.*)$/
        $log.info "User #{$1} (#{@users[$1].nick}) is away (#{$2})."
        @users[$1].away = true      
      elsif line =~ /^:(\w{9}) NICK (\S+) :(\d+)$/
        uid = $1
        oldnick = @users[uid].nick
        @users[uid].nick = $2
        $log.info "Nick change for #{$1}: #{oldnick} -> #{@users[uid].nick}"
      elsif line =~ /^:(\w{9}) QUIT :(.*)$/
        $log.info "User #{@users[$1].nick} quit (#{$2})"
        @users.delete $1
      elsif line =~ /^:(\w{9}) ENCAP \S{1} REALHOST (.*)$/
        @users[$1].realhost = $2
        $log.info "Realhost for #{$1} (#{@users[$1]}) is #{@users[$1].realhost}."
      elsif line =~ /^:(\w{9}) ENCAP \S{1} LOGIN (.*)$/
        @users[$1].account = $2
        $log.info "#{@users[$1]} logged in as #{@users[$1].account}."
      elsif line =~ /^:(\w{9}) ENCAP \S{1} CERTFP (.*)$/
        #do nothing
      else
        $log.info "Unhandled user input: #{line}"
      end
    end
  
    def server_input(line)
      sid = Configru.link.serverid
      name = Configru.link.name
      
      if line =~ /^:(\w{3}) UID (\S+) (\d{1,2}) (\d{10}) \+([a-zA-Z]*) (\S+) (\S+) (\S+) ([0-9]\w{2}[A-Z][A-Z0-9]{5}) :(.*)$/
        user = RServ::IRC::User.new($2, $9, $3, $5, $6, $7, $8, $10)
        @users[user.uid] = user
        $log.info "New user #{user.uid} on #{user.sid} (#{@servers[$1].hostname}). Host: #{user.nick}!#{user.username}@#{user.hostname} (#{user.ip}) | Modes: +#{user.mode}"
      elsif line =~ /^:(\w{3}) SID (\S+) (\d{1,2}) ([0-9][0-9A-Z]{2}) :(.*)$/
        server = RServ::IRC::Server.new($4, $2, $3, $5)
        $log.info "New server: #{server.hostname} (#{server.sid}) [#{server.gecos}]"
        @servers[server.sid] = server
        send(":#{sid} PING #{name} :#{server.sid}")        
      else
        $log.info "Unhandled server input: #{line}"
      end
    end
    
	end
end

RServ::Protocols::TS6.new
