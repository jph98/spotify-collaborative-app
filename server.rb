#!/usr/bin/env ruby

require "sinatra"
require "ostruct"
require "curb"

require_relative "spotifybridge"

# Options
set :public_folder, "public"
set :port, 5000

layout 'layout'

DEBUG = false

# Configure the initial application
configure do
  	set :show_exceptions, true

end

before do

end

# Global error
error do
  	e = request.env['sinatra.error']
  	puts e.to_s
  	puts e.backtrace.join("\n")
  	"Application error"
end

##################################################
# ROUTES
##################################################

# Display list of applications
get "/" do

    client = SpotifyBridge.new()

    @trackinfo = {}
    tracks = client.get_tracks()

    tracks.each do |t|
        @trackinfo[t.external_urls["spotify"]] = t
    end

    @playlist = client.playlist()

   	erb :playlist
end