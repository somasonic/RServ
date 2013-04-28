#!/usr/bin/env ruby
$:.unshift File.dirname(__FILE__)

require 'logger'
require 'configru' # https://github.com/programble/configru

require 'lib/events'
require 'lib/link'
require 'lib/plugins'

# Basic initialization: config, log, events
$log = Logger.new('logs/rserv.log')
#$log = Logger.new(STDOUT)
$log.level = Logger::INFO
$log.info "---------------------"
$log.info "RServ session started"
$log.info "---------------------"
$log.info ""

Configru.load('etc/rserv.yaml') do
  option_group :server do
    option :addr, String, 'upstream.irc.net'
    option :port, Fixnum, 6667
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
$event = RServ::Events.new # Global variables are easy


# TODO
#
# Make a PID file
#

# Get the protocol loaded. Protocol support at
# current is kinda bad, but the basic concept
# is there.

proto = require "lib/protocols/#{Configru.link.protocol}"
unless proto
  $log.fatal "Couldn't load protocol #{Configru.link.protocol}. Exiting."
end

# The link, this is basically an event-socket.
$log.info "Attempting to initialise link..."
RServ::Link.new(Configru.server.addr, Configru.server.port, true)

# Plugins. There is no need for a special loader
# since they auto-register and it's simpler and
# easier to do it this way.
Configru.plugins.each do |p| 
  break if p == "none" # nice config
  Thread.new do 
    $log.info "Loading plugin: #{p}"
    RServ::Plugin.load "plugins/#{p}.rb"
  end
end

# Keep on truckin'
loop { sleep 3600 }
