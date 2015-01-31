#!/usr/bin/env ruby

require "rufus-scheduler"
require_relative "spotifyadapterlinux"

INTERVAL = 1
scheduler = Rufus::Scheduler.new()
puts "Created scheduler"

adapter = SpotifyAdapterLinux.new()

while true
	scheduler.every "2s" do

	    puts "\n\nFire scheduler\n\n"
	    artist, title = adapter.songinfo()

	    puts "Current song: #{artist} #{title}"
	    sleep INTERVAL
	end
end