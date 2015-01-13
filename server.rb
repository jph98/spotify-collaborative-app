#!/usr/bin/env ruby

require "sinatra"
require "ostruct"
require "json"

require_relative "spotifywebbridge"
require_relative "spotifyadapterlinux"

# Options
set :public_folder, "public"
set :port, 5000

layout 'layout'

DEBUG = false

def get_preview_image(images)
    min = 1000
    preview = ""
    images.each do |i|
        if i["height"] < min
            preview = i
        end
    end
    return preview
end 

def get_fullsize_image(images)
    max = 0
    fullsize = ""
    images.each do |i|
        if i["height"] > max
            fullsize = i
        end
    end
    return fullsize
end

# Configure the initial application
configure do

  	set :show_exceptions, true

    @@bridge = SpotifyWebBridge.new()
    @@trackinfo = {}

    tracks = @@bridge.get_tracks()

    tracks.each do |t|

        # TODO: Either change to an array or split into two lists
        # (played_songs, voted_songs, to_play_songs)
        @@trackinfo[t.id] = OpenStruct.new(:name => t.name,
                                          :album => t.album,
                                          :artist => t.artists[0].name,
                                          :duration_ms => t.duration_ms,
                                          :explicit => t.explicit,
                                          :external_ids => t.external_ids,
                                          :track_number => t.track_number,
                                          :imagepreview => get_preview_image(t.album.images),
                                          :imagefullsize => get_fullsize_image(t.album.images),
                                          :votes => [])
    end

    @playlist = @@bridge.playlist()

    if @playlist.nil?
        puts "Could not talk to api.spotify.com"  
        exit
    else
        puts "Loaded playlist: #{@playlist.name}"
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

    adapter = SpotifyAdapterLinux.new()
    @artist, @title = adapter.songinfo()

    puts "Currently playing: #{@artist} - #{@title}"

    @playlist = @@bridge.playlist()    

   	erb :playlist
end

get "/playing" do

    content_type :json
    puts "Requesting currently playing..."
    adapter = SpotifyAdapterLinux.new()
    artist, title = adapter.songinfo()
    puts "Currently playing: #{artist} - #{title}"
    output = {:artist => "#{artist}", :title => "#{title}"}.to_json
    return output
end

post "/vote" do

    puts "Got vote"

    id = params["vote"]

    @@trackinfo.each_key do |k|

        puts "Key: #{k} id #{params["vote"]}"
        if k.eql? id

            if !@@trackinfo[k].votes.include? request.ip

                puts "User #{request.ip} voted for song: #{@@trackinfo[k].artist} #{@@trackinfo[k].name}"
                @@trackinfo[k].votes << request.ip
                puts @@trackinfo[k].votes.size()
                @@bridge.reorder_tracks(@@trackinfo)

                break
            else
                puts "User #{request.ip} should not be able to vote for #{t.name}"
            end
        end    
    end

    redirect "/"
end