#!/usr/bin/env ruby
$:.unshift File.dirname(__FILE__)

require 'logger'
require 'lib/config'
require 'lib/events'
require 'lib/link'
require 'lib/plugins'


# Basic initialization: config, log, events
$log = Logger.new('log/rserv.log')
$log.info "Log initialised"
$config = RServ::Config.new('conf/rserv.yaml')
$event = RServ::Events.new # Global variables are easy

# Get the protocol loaded. Protocol support at
# current is kinda bad, but the basic concept
# is there.

proto = require "lib/protocols/#{$config['link']['protocol']}"
unless proto
  $log.fatal "Couldn't load protocol #{$config['link']['protocol']}. Exiting."
end

# The link, this is basically an event-socket.
$log.info "Attempting to initialise link..."
RServ::Link.new($config['server']['addr'], $config['server']['port'], true)

# Plugins. There is no need for a special loader
# since they auto-register and it's simpler and
# easier to do it this way.
$config['plugins'] ||= []
$config['plugins'].each do |p| 
  Thread.new do 
    $log.info "Loading plugin: #{p}"
    RServ::Plugin.load "plugins/#{p}.rb"
  end
end

# Keep on truckin'
loop { sleep 3600 }
