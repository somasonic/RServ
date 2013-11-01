
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
    @control = RServ::IRC::PseudoClient.new("Sporks", "sporks", "rserv.interlinked.me", "Utensil Services", "S", ["#Sporks", "#opers", "#realtalk"])
    
    $event.add(self, :on_input, "link::input")
  end
  
  def on_unload
    @control.quit
  end
      
  def on_input(line)
    if line =~ /^:(\w{9}) PRIVMSG (#\S*) :(.*)$/i
      return unless @control.channels.include?($2)
      user = $protocol.get_uid($1)
      command($2, user, $3)
    end
  end
  
  private
  
  def command(chan, user, command)
    if command =~ /^!trigger\s*/i
      @control.privmsg(chan, "#{RED}#{BOLD} --- TRIGGER WARNING --- DO NOT READ IF YOU ARE EASILY OFFENDED OR CANNOT TAKE A JOKE ---#{RED}#{BOLD}")
    elsif command =~ /^!rules\s*$/i
      @control.privmsg(chan, "Network rules: https://wiki.interlinked.me/page/Network_Rules || Channel rules: https://wiki.interlinked.me/page/Sporks/rules || Summary: Don't be a dick!")
    elsif command =~ /^!wiki\s*$/i
      @control.privmsg(chan, "https://wiki.interlinked.me/ - please register to edit :)")
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

  def msg(t, msg)
    @control.privmsg(t, msg)
  end
end
