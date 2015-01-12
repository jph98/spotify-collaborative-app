#!/usr/bin/env ruby

require "sinatra"
require "ostruct"

require_relative "spotifywebbridge"
require_relative "spotifyadapterlinux"

# Options
set :public_folder, "public"
set :port, 5000

layout 'layout'

DEBUG = false

# Configure the initial application
configure do
  	set :show_exceptions, true

    @bridge = SpotifyWebBridge.new()
    @trackinfo = {}

    adapter = SpotifyAdapterLinux.new()
    @artist, @title = adapter.songinfo()

    tracks = @bridge.get_tracks()

    tracks.each do |t|

        @trackinfo[t.id] = OpenStruct.new(:name => t.name,
                                          :album => t.album,
                                          :primary_artist => t.artists[0].name,
                                          :duration_ms => t.duration_ms,
                                          :explicit => t.explicit,
                                          :external_ids => t.external_ids,
                                          :track_number => t.track_number,
                                          :number_of_votes => 0)

        puts @trackinfo[t.id]
        puts t.album.images
        puts "\n"
    end

    @playlist = @bridge.playlist()

    if @playlist.nil?
        puts "Could not talk to api.spotify.com"  
        exit
    end

    puts "SpotifyBridge started..."    
end

# Before each request
before do
end

# Global error
error do

  	e = request.env['sinatra.error']
  	puts e.to_s
  	puts e.backtrace.join("\n")
end

##################################################
# ROUTES
##################################################

get "/" do

   	erb :playlist
end

post "/vote" do

    id = params["vote"]

    @trackinfo.each_key do |k|

        if k.eql? id

            t = @trackinfo[k]
            if !t.votes.include? request.ip
                puts "User #{request.ip} voted for song: #{t.id} #{t.name}"
                t.votes += request.ip
                @bridge.reorder_tracks(@trackinfo)
                break
            else
                puts "User #{request.ip} should not be able to vote for #{t.name}"
            end

        end
    end

    redirect "/"
end