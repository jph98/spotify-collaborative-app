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

def check_track_vote(trackinfo, id)

    trackinfo.each_key do |k|

        puts "Key: #{k} id #{params["vote"]}"
        if k.eql? id

            puts "\nIncrementing vote for #{trackinfo[k].name} #{trackinfo[k].album}"
            increment_vote(trackinfo[k])
            return true
        end    
    end
    return false
end

def increment_vote(track)

    if !track.votes.include? request.ip

        puts "User #{request.ip} voted for song: #{track.artist} #{track.name}"
        track.votes << request.ip
        puts track.votes.size()
    else
        puts "User #{request.ip} should not be able to vote for #{t.name}"
    end
end

# Configure the initial application
configure do

  	set :show_exceptions, true

    @@bridge = SpotifyWebBridge.new()
    @@trackinfo = {}

    tracks = @@bridge.get_tracks()

    adapter = SpotifyAdapterLinux.new()
    artist, title = adapter.songinfo()

    @@played, @@playing, @@voted, @@other = @@bridge.get_track_groups(artist, title)

    puts "Played #{@@played.size()}"
    puts "Voted #{@@voted.size()}"
    puts "Other #{@@other.size()}"

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

    tracks = {}
    @@played.each_key do |p| 
        tracks[p] = @@played[p]
    end

    tracks[@@playing.id] = @@playing

    if check_track_vote(@@voted, id)
        #@@voted.sort_by! { |k,v| v.votes.size() }.reverse
        @@voted.each_key do |k|
            puts "Track: #{@@voted[k].name} #{@@voted[k].artist} #{@@voted[k].votes}"
        end
        puts "Voted done"
    elsif check_track_vote(@@other, id)            
        @@voted[id] = @@other[id]
        @@other.delete(id)
    end

    tracks.each_key do |k|
        puts "\tAfter Voting... tracks: #{tracks[k].name} #{tracks[k].album} #{tracks[k].votes.size()}"
    end

    # TODO: Glue all the tracks back togethe

    redirect "/"
end