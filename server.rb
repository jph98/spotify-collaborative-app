#!/usr/bin/env ruby

require "sinatra"
require "sinatra/streaming"
require "ostruct"
require "json"
require "rufus-scheduler"

require_relative "spotifywebbridge"
require_relative "spotifyadapterlinux"

# Options
set :public_folder, "public"
set :port, 5000

set server: 'thin', connections: []

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

    @@scheduler = Rufus::Scheduler.new()
    puts "Created scheduler"
    @@scheduler.every "2s" do
        puts "Firing scheduler"
        artist, title = adapter.songinfo()
        settings.connections.each {|out| out << %Q^data: { "artist": "#{artist}", "title": "#{title}"}\n\n^}
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

get '/stream', provides: 'text/event-stream' do

    stream :keep_open do |out|        
        puts "Received connection: #{out}"
        settings.connections << out
        out.callback {settings.connections.delete(out)}
    end
end

get '/playing' do

    @scheduler = Rufus::Scheduler.new()
    puts "Created scheduler"
    @scheduler.every "3s" do
        console.log("Firing scheduler")
        settings.connections.each {|out| out << %Q^data: {"ctrl": "params"}\n\n^}
    end
end

# get "/playing" do

#     content_type :json
#     puts "Requesting currently playing..."
#     adapter = SpotifyAdapterLinux.new()
#     artist, title = adapter.songinfo()
#     puts "Currently playing: #{artist} - #{title}"
#     output = {:artist => "#{artist}", :title => "#{title}"}.to_json
#     return output
# end

get "/search" do
    
    @playlist = @@bridge.playlist()    

    erb :search
end

post "/vote" do

    puts "Got vote"

    id = params["vote"]

    if check_track_vote(@@voted, id)
        #@@voted.sort_by! { |k,v| v.votes.size() }.reverse
        @@voted.each_key do |k|
            puts "Track: #{@@voted[k].name} #{@@voted[k].artist} #{@@voted[k].votes}"
        end
        puts "Voted done"
    elsif check_track_vote(@@other, id)            
        @@voted[id] = @@other[id]
        @@other.delete(id)
        puts "Added non voted song to the voted section"
    end

    @@voted.each_key do |k|
        puts "\tVOTED... : #{@@voted[k].name} #{@@voted[k].album} #{@@voted[k].votes.size()}"
    end

    @@other.each_key do |k|
        puts "\nOTHER... : #{@@other[k].name} #{@@other[k].album} #{@@other[k].votes.size()}"
    end

    tracks = {}
    puts "\nplayed"
    @@played.each_key do |p|
        puts "Played: #{@@played[p].id} #{@@played[p].name} #{@@played[p].artist} #{@@played[p].votes.size}"
        tracks[p] = @@played[p]
    end

    tracks[@@playing.id] = @@playing

    puts "\nvoted"
    @@voted.each_key do |p|
        puts "Voted: #{@@voted[p].id} #{@@voted[p].name} #{@@voted[p].artist} #{@@voted[p].votes.size}"
        tracks[p] = @@voted[p]
    end

    puts "\nother"
    @@other.each_key do |p|
        puts "Other: #{@@other[p].id} #{@@other[p].name} #{@@other[p].artist} #{@@other[p].votes.size}"
        tracks[p] = @@other[p]
    end

    puts "\nSize: #{tracks.size}, tracks...."
    tracks.each_key do |p|
        puts "\n\nTracks: #{tracks[p].name} #{tracks[p].artist} #{tracks[p].votes.size}"
    end

    @@bridge.store_tracks(tracks)


    redirect "/"
end