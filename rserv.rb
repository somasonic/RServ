#!/usr/bin/env ruby
#
#Copyright (C) 2013 Andrew Northall
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), 
#to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
#and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
#DEALINGS IN THE SOFTWARE.

$:.unshift File.dirname(__FILE__)

require 'logger'
require 'configru' # https://github.com/programble/configru

require 'lib/events'
require 'lib/link'
require 'lib/plugins'

# Basic initialization: config, log, events
$log = Logger.new("logs/rserv.log")
$log.level = Logger::DEBUG ##DONT CHANGE
$log.info "---------------------"
$log.info "RServ session started"
$log.info "---------------------"
$log.info ""
$log.level = Logger::INFO #set loglevel here

# This is a hack to allow for some weird bug in configru
module Boolean; end
class TrueClass; include Boolean; end
class FalseClass; include Boolean; end

# Config
Configru.load('etc/rserv.yaml') do
  option_group :server do
    option :addr, String, 'upstream.irc.net'
    option :port, Fixnum, 6697
    option :ssl, Boolean, 'yes'
    option :reconnectdelay, Fixnum, 30
  end
  option_group :link do
    option :name, String, 'rserv.irc.net'
    option :serverid, String, '0RS'
    option :description, String, 'Ruby Services'
    option :protocol, String, 'ts6'
    option :recvpassword, String, 'password-here'
    option :sendpassword, String, 'password-here'
  end
  option_array :channels, String, ['opers']
  option_array :plugins, String, ['none']
end

# Initialise event handler
# Global variables are easy
$event = RServ::Events.new 

# Get the protocol loaded.
proto = require "lib/protocols/#{Configru.link.protocol}"
unless proto
  $log.fatal "Couldn't load protocol #{Configru.link.protocol}. Exiting."
end

# Plugins. There is no need for a special loader
# since they auto-register and it's simpler and
# easier to do it this way.
Configru.plugins.each do |p| 
  break if p == "none" # nice config
  $log.info "Loading plugin: #{p}"
  RServ::Plugin.load p
end

# The link, this is basically an event-socket.
$log.info "Attempting to initialise link..."
RServ::Link.new(Configru.server.addr, Configru.server.port, true)

# Keep on truckin'
loop { sleep 3600 }
