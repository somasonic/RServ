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

require 'resolv'
require 'googl'
require 'cgi'
require 'net/http'
require 'json'

class Sporks < RServ::Plugin
  
  def initialize
    @control = RServ::IRC::PsuedoClient.new("Sporks", "sporks", "rserv.interlinked.me", "Utensil Services", "S", ["#Sporks", "#opers"])
    
    @user = nil
    
    begin
      @karma = load("data/karma")
    rescue
      @karma = Hash.new
      save(@karma, "data/karma")
    end
    
    begin 
      @strings = load("data/strings")
    rescue
      @strings = Hash.new
      @strings["help"] = "Use ;set [stringname] [content] to set a string. Use ;[stringname] to recall."
      save(@strings, "data/strings")
    end
    
    $event.add(self, :on_input, "link::input")
  end
  
  def on_unload
    @control.quit
  end
      
  def on_input(line)
    if line =~ /:(\w{9}) PRIVMSG (#\S*) :(.*)$/i
      return unless @control.channels.include?($2)
      user = $protocol.get_uid($1)
      command($2, user, $3)
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
    if command =~ /\[\[(\S+)\]\]/
      page = $1
      return if page =~ /sroracle/i
      @control.privmsg(chan, "[[#{page}]]: https://wiki.interlinked.me/page/#{page}")
    elsif command =~ /^!rules\s*/i
      @control.privmsg(chan, "Network rules: https://wiki.interlinked.me/page/Network_Rules || Channel rules: https://wiki.interlinked.me/page/Sporks/rules || Summary: Don't be a dick!")
    elsif command =~ /^!wiki\s*/i
      @control.privmsg(chan, "https://wiki.interlinked.me/ - please register to edit :)")
    elsif command =~ /^!(hosts?|r?dns) (\S+)\s*$/i
      addr = $2
      resolver = Resolv::DNS.new
      addrs = resolver.getaddresses(addr)
      if addrs.empty?
        begin
          addrs = resolver.getnames(addr)
          if addrs.empty?
            @control.privmsg(chan, "No hosts found for #{addr}.")
          else
            reply = "Hosts for #{addr}: "
            addrs.each {|a| reply = reply + a.to_s + " " }
            @control.privmsg(chan, reply)
          end
        rescue Resolv::ResolvError
          @control.privmsg(chan, "No hosts found for #{addr}.")
        end
      else
        reply = "Hosts for #{addr}: "
        addrs.each {|a| reply = reply + a.to_s + " " }
        @control.privmsg(chan, reply)
      end
    elsif command =~ /^!karma\s*$/i
      top = ordered_karma()[0..9]
      str = "[Top Karma] "
      cnt = 1
      top.each { |k,v| str = str + "[#{cnt}] #{k} => #{v} "; cnt += 1}
      @control.notice(user.uid, str)
    elsif command =~ /^!(lastquote|quote last)\s*$/i
      begin
        quote = get_last_quote()
      rescue
        msg(chan, "Error fetching quote")
        return
      end
      msg(chan, "[#{quote['id']}] [#{Time.at(quote['date'].to_i).utc}] [Rating: #{quote['rating']}] [URL: #{Googl.shorten("https://quotes.interlinked.me/?#{quote['id']}").short_url} ] #{CGI.unescape_html(quote['quote'].gsub(/\r\n/, ' | '))}")
    elsif command =~ /^!quote\s*$/i
      begin
        quote = get_random_quote()
      rescue
        msg(chan, "Error fetching quote")
        return
      end
      msg(chan, "[#{quote['id']}] [#{Time.at(quote['date'].to_i).utc}] [Rating: #{quote['rating']}] [URL: #{Googl.shorten("https://quotes.interlinked.me/?#{quote['id']}").short_url} ] #{CGI.unescape_html(quote['quote'].gsub(/\r\n/, ' | '))}")
    elsif command =~ /^!quote (\d+)\s*$/i  
      begin
        quote = get_quote($1)
      rescue
        msg(chan, "Error fetching quote")
        return
      end
      if quote == nil
        msg(chan, "quote doesn't exist")
      else
        msg(chan, "[#{quote['id']}] [#{Time.at(quote['date'].to_i).utc}] [Rating: #{quote['rating']}] [URL: #{Googl.shorten("https://quotes.interlinked.me/?#{quote['id']}").short_url} ] #{CGI.unescape_html(quote['quote'].gsub(/\r\n/, ' | '))}")
      end
    elsif command =~ /^!karma (\S+)\s*$/
      @control.privmsg(chan, "Karma for #{$1}: #{@karma[$1.downcase]}")
    elsif command =~ /^;set (\S+) (.+)\s*/i
      @strings[$1] = $2.strip
      save(@strings, "data/strings")
      msg(chan, "#{$1} => #{$2}")
    elsif command =~ /^;(\S+)\s*/i
      if @strings.has_key?($1)
        msg(chan, "#{$1} => #{@strings[$1]}")
      end
    elsif command =~ /(\S)+\+\+/ or command =~ /(\S)+--/
      karma_process(command, user)
    end
  end

  def get_quote(id)
    uri = URI.parse("https://quotes.interlinked.me/api.php?cmd=get&qid=#{id}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request).body
    JSON.parse(response)[0]
  end

  def get_last_quote
    uri = URI.parse("https://quotes.interlinked.me/api.php?cmd=last")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request).body
    JSON.parse(response)[0]
  end

  def get_random_quote
    uri = URI.parse("https://quotes.interlinked.me/api.php?cmd=random")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request).body
    JSON.parse(response)
  end

  def karma_process(line, origin)
    words = line.split(" ")
    changed = 0 
    words.each do
      |w|
      if w =~ /^(.+)\+\+$/
        stripped = $1
        @karma[stripped.downcase] += 1 unless stripped =~ /#{origin.nick}/i
        changed = 1
      elsif w =~ /^(.+)\-\-$/
        stripped = $1
        @karma[stripped.downcase] -= 1 unless stripped =~ /#{origin.nick}/i
        changed = 1
      end
    end
    save(@karma, "data/karma")
  end
  
  def ordered_karma
    @karma.sort_by{|k,v| v}.reverse
  end
  
  def msg(t, msg)
    @control.privmsg(t, msg)
  end
end
