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
require 'lastfm'
require 'active_support/core_ext/integer/inflections'
 
class LastFM < RServ::Plugin
 
  def initialize
    @control = RServ::IRC::PsuedoClient.new("LastFM", "music", "rserv.interlinked.me", "LastFM Services", "S")
 
    @users = load("data/lastfm-users")
    @data = load("data/lastfm-data")
    @auth = load("data/lastfm-auth")
    
    @lastfm = Lastfm.new(@data['api_key'], @data['api_secret'])
 
    $event.add(self, :on_input, "link::input")
    $event.add(self, :on_burst, "server::connected")
 
    on_burst if $protocol.established
  end
 
  def on_burst
    @data['channels'] = Array.new unless @data.has_key?("channels")
    @data['channels'].each { |c| @control.join(c, false) }
  end
 
  def on_unload
    @control.quit
    save(@users, "data/lastfm-users")
    save(@data, "data/lastfm-data")
    save(@auth, "data/lastfm-auth")
  end
 
  def on_input(line)
    if line =~ /:(\w{9}) PRIVMSG (#\S*) :(.*)$/i
      return unless @control.channels.include?($2)
      user = $protocol.get_uid($1)
      command($2, user, $3)
    elsif line =~ /:(\w{9}) PRIVMSG (#{@control.nick}|#{@control.uid}) :(.*)$/i
      user = $protocol.get_uid($1)
      private_command(user, $3)
    end
  end
 
  private
 
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
 
  def command(chan, user, command)
    unless @data['channels'].map{|c|c.downcase}.include?(chan.to_s.downcase)
      msg(user, "That channel is not enabled for LastFM. Please ask an operator (/stats p) to enable it.")
      return
    end
    
    if command =~ /^!np\s*$/i
      user = user.nick unless @users.has_key?(user.account)
      reply = now_playing(user)
      msg(chan, reply)
    elsif command =~ /^!l(ove|)np\s*$/i
      unless @users.has_key?(user.account) and @auth.has_key?(@users[user.account])
        msg(user, "You must first link and authorise your LastFM account to use this command.")
        return
      end
      @control.notice(user, love(user))
      msg(chan, now_playing(user))
    elsif command =~ /^!tag (.+)$/i
      msg(chan, add_tags(user, $1))
    elsif command =~ /^!url (\S+)\s*$/i
      user = $1
      $protocol.users.map {|uid, u| user = u if u.nick.downcase == $1.downcase or u.account == $1.downcase}
      user = @users[user.account] if user.class == RServ::IRC::User and @users.has_key?(user.account)
      msg(chan, "URL for #{$1} (#{user}): http://last.fm/user/#{user}")
    elsif command =~ /^!np (\S+)\s*$/i
      user = $1
      $protocol.users.map {|uid, u| user = u if u.nick.downcase == $1.downcase or u.account == $1.downcase}
      reply = now_playing(user)
      msg(chan, reply)
    elsif command =~ /^!(cp|compare) (\S+)\s*$/i
      if user.account == nil
        msg(user, "You must identify with NickServ before using this command.")
        return
      end
      unless @users.has_key?(user.account)
        msg(user, "You must first link your LastFM account to use this command. Please try /msg #{@control.nick} LINK [lastfm username]")
        return
      end
      user1, nick1 = @users[user.account], user.nick
      user2, nick2 = $2, $2
      $protocol.users.map {|uid, u| user2 = @users[u.account] if u.nick.downcase == $2.downcase and @users.has_key?(u.account)}
      msg(chan, compare(user1, user2, nick1, nick2))
    elsif command =~ /^!(cp|compare) (\S+)\s+(\S+)\s*$/i
      user1, nick1 = $2, $2
      user2, nick2 = $3, $3
      $protocol.users.map {|uid, u| user1 = @users[u.account] if u.nick.downcase == $2.downcase and @users.has_key?(u.account)}
      $protocol.users.map {|uid, u| user2 = @users[u.account] if u.nick.downcase == $3.downcase and @users.has_key?(u.account)}
      msg(chan, compare(user1, user2, nick1, nick2))
    end
    
    if command =~ /^!(un|)love\s*$/i
      if @auth.has_key?(@users[user.account])
        if $1 == "un"
          @control.notice(user, love(user, true))
        else
          @control.notice(user, love(user))
        end
      else
        msg(user, "Error: you must authorise your LastFM account to use this command.")
      end
    end
  end
 
  def private_command(user, command)
    if user.account == nil
      msg(user, "You must identify with NickServ before using this command.")
      return
    end
      
    if command =~ /^!?link (\S+)\s*$/i
      begin
        @lastfm.user.get_info($1)
      rescue Lastfm::ApiError
        msg(user, "Error: could not find a LastFM user by that name.")
        return
      end
      @users[user.account] = $1
      msg(user, "The account #{$1} has been linked with the NickServ account #{user.account}.")
      save(@users, "data/lastfm-users")
    end
    
    unless @users.has_key?(user.account)
      msg(user, "You must first link your LastFM account to use this command. Please try /msg #{@control.nick} LINK [lastfm username]")
      return
    end
    
    if command =~ /^!?np (#\S*)\s*$/i
      unless @data['channels'].map{|c|c.downcase}.include?($1.downcase)
        msg(user, "That channel is not enabled for LastFM. Please ask an operator (/stats p) to enable it.")
        return
      end
      reply = now_playing(user)
      msg($1, reply)
    elsif command =~ /^!?l(ove|)np\s*(#\S*|)\s*$/i
      unless @auth.has_key?(@users[user.account])
        msg(user, "You must first authorise your LastFM account to use this command.")
        return
      end
      @control.notice(user, love(user))
      target = user.uid
      target = $2 if @data['channels'].map{|c|c.downcase}.include?($2.downcase)
      msg(target, now_playing(user))
    elsif command =~ /^!?tag (.+)$/i
      @control.notice(user, add_tags(user, $1))
    elsif command =~ /^!?np\s*$/i
      reply = now_playing(user)
      msg(user, reply)
    elsif command =~ /^!?authori(z|s)e\s*$/i
      msg(user, authorise(@users[user.account]))
    elsif command =~ /^!?enable (#\S+)\s*$/i
      return unless user.oper?
      @data['channels'].push $1
      save(@data, "data/lastfm-data")
      msg(user, "enabled channel #{$1}")
      @control.join($1)
    elsif command =~ /^!?disable (#\S+)\s*$/i
      return unless user.oper?
      @data['channels'].delete $1
      save(@data, "data/lastfm-data")
      msg(user, "leaving channel #{$1}")
      @control.part($1)
    elsif command =~ /^!?(cp|compare) (\S+)\s*$/i
      user1, nick1 = @users[user.account], user.nick
      user2, nick2 = $2, $2
      $protocol.users.map {|uid, u| user2 = @users[u.account] if u.nick.downcase == $2.downcase and @users.has_key?(u.account)}
      msg(user, compare(user1, user2, nick1, nick2))
    elsif command =~ /^!?(cp|compare) (\S+)\s+(\S+)\s*$/i
      user1, nick1 = $2, $2
      user2, nick2 = $3, $3
      $protocol.users.map {|uid, u| user1 = @users[u.account] if u.nick.downcase == $2.downcase and @users.has_key?(u.account)}
      $protocol.users.map {|uid, u| user2 = @users[u.account] if u.nick.downcase == $3.downcase and @users.has_key?(u.account)}
      msg(user, compare(user1, user2, nick1, nick2))
    end
    
    if command =~ /^!?(un|)love\s*$/i
      if @auth.has_key?(@users[user.account])
        if $1 == "un"
          @control.notice(user, love(user, true))
        else
          @control.notice(user, love(user))
        end
      else
        msg(user, "Error: you must authorise your LastFM account to use this command.")
      end
    end
  end
  
  def add_tags(user, tags)
    unless @auth.has_key?(@users[user.account])
      return "Error: you must link and authorise your LastFM account to use this. Please /msg LastFM HELP for more information."
    end
    
    tags = tags.split(", ")
    return "Error: you can only add a maximum of ten tags" if tags.size >= 10
    
    @lastfm.session = @auth[@users[user.account]] 
    begin
      track = @lastfm.user.get_recent_tracks(@users[user.account])[0]
      artist = track["artist"]["content"]
      track = track["name"]
      @lastfm.track.add_tags(:artist => artist, :track => track, :tags => tags.join(","))
    rescue Lastfm::ApiError => err
      msg("#services", "Error code #{err.code} from LastFM on add_tags (user=#{user.nick},tags=#{tags.join(",")},artist=#{artist},track=#{track})") 
      return "Error: could not perform the operation. Please try again later."
    end
    return "Added tags to \"#{track}\" by #{artist}."
  end
    
  def compare(user1, user2, nick1, nick2)
    begin
      result = @lastfm.tasteometer.compare(:type1 => "user", :type2 => "user", :value1 => user1, :value2 => user2, :limit => 10)
    rescue Lastfm::ApiError => err
      msg("#services", "Error code #{err.code} from LastFM on compare [user1=#{user1}, user2=#{user2}, nick1=#{nick1}, nick2=#{nick2}]")
      return "Error: one of the two users specified does not exist." if err.code == 7
      return "Error: could not get comparison from Last.FM. This can be due to low playcounts of one user, or if one user does not exist."
    end
    artists = Array.new
    score = result["score"].to_f * 100
    score = score.to_s[0..4] + "%"
    result["artists"]["artist"].each{|a| artists << a["name"]} unless result["artists"]["matches"] == "0" or result["artists"]["matches"] == "1"
    if result["artists"]["matches"] == "1"
      return "#{nick1} (#{user1}) and #{nick2} (#{user2}) and musically #{score} compatible. They have only one common artist: #{result["artists"]["artist"]["name"]}."
    elsif artists.size > 0
      return "#{nick1} (#{user1}) and #{nick2} (#{user2}) are musically #{score} compatible. Common artists include: #{artists.join(", ")}."
    else
      return "#{nick1} (#{user1}) and #{nick2} (#{user2}) are musically #{score} compatible. They have no artists in common!"
    end
  end
  
  def authorise(lastfm_username)
    if @auth.has_key?("_#{lastfm_username}")
      begin
        @auth[lastfm_username] = @lastfm.auth.get_session(:token => @auth["_#{lastfm_username}"])["key"]
      rescue Lastfm::ApiError => err
        msg("#services", "Error code #{err.code} from LastFM on authorise [token=#{@auth["_#{lastfm_username}"]}, username=#{lastfm_username}]")
        @auth.delete("_#{lastfm_username}")
        save(@auth, "/data/lastfm-auth")
        return "Error: could not authenticate with LastFM. Please try again, or try later."
      end
      @auth.delete("_#{lastfm_username}")
      save(@auth, "/data/lastfm-auth")
      return "Authorised successfully!"
    else
      token = @lastfm.auth.get_token
      @auth["_#{lastfm_username}"] = token
      return "Please visit http://last.fm/api/auth/?api_key=#{@data["api_key"]}&token=#{token} and verify our permission to access your account, and then run /msg LASTFM AUTHORISE again."
    end
  end
  
  def love(user, unlove = false)
    unless @auth.has_key?(@users[user.account])
      return "Error: you must link and authorise your LastFM account to use this. Please /msg LastFM HELP for more information."
    end
    @lastfm.session = @auth[@users[user.account]] 
    begin
      track = @lastfm.user.get_recent_tracks(@users[user.account])[0]
      artist = track["artist"]["content"]
      track = track["name"]
      if unlove
        @lastfm.track.unlove(:artist => artist, :track => track)
      else
        @lastfm.track.love(:artist => artist, :track => track)
      end
    rescue Lastfm::ApiError => err
      msg("#services", "Error code #{err.code} from LastFM on love (unlove=#{unlove}) [user=#{user.nick}, account=#{user.account}, artist=#{artist}, track=#{track}]")
      return "Error: could not perform the operation. Please try again later."
    end
    if unlove
      return "Unloved \"#{track}\" by #{artist}."
    else
      return "Loved \"#{track}\" by #{artist}."
    end
  end
      
  def now_playing(user)
    if user.class == RServ::IRC::User
      usernick = user.nick
      useraccount = user.account
      useraccount = @users[useraccount] if @users.has_key?(useraccount)
    else
      usernick, useraccount = user, user
    end
    begin
      track = @lastfm.user.get_recent_tracks(useraccount)[0]
      info = @lastfm.track.get_info(:artist => track["artist"]["content"], :track => track["name"], :username => useraccount)
 
      artist = track["artist"]["content"]
      title = track["name"]
      nowplaying = track["nowplaying"]
      album = track["album"]["content"]
      userplaycount = info["userplaycount"].to_i + 1 #+1 so 0 plays == 1st
      userloved = info["userloved"].to_i
      listeners = info["listeners"]
      playcount = info["playcount"]
      
      tags = Array.new
      info["toptags"]["tag"].map{|t| tags << t["name"]} unless info["toptags"].empty?
      
      if userloved == 1 then lovedstr = " a loved track" else lovedstr = "" end
      if nowplaying == "true" then playing_str = "is now playing" else playing_str = "last played" end
      if album == nil then albumstr = "" else albumstr = ", from the album #{album}" end
      tag_str = "Tags: #{tags.join(", ")}." unless tags.empty?
      
      reply = "#{usernick} (#{useraccount}) #{playing_str}#{lovedstr} \"#{title}\" by #{artist}#{albumstr} for the #{userplaycount.ordinalize} time. This track has been played #{playcount} times by #{listeners} listeners. #{tag_str}"
    rescue Lastfm::ApiError => err
      msg(user, "Error: could not get recent tracks.")
      msg("#services", "Error code #{err.code} from LastFM on now_playing. Message: \"#{err.message}\"")
    end
  end
 
  def msg(t, msg)
    @control.privmsg(t, msg)
  end
end
