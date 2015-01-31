#!/usr/bin/env ruby

require "sinatra"
require "sinatra/streaming"
require "ostruct"
require "json"

require_relative "spotifywebbridge"

# Options
set :public_folder, "public"
set :port, 5000
set :bind, '0.0.0.0'
set connections: []
set :server, 'thin'  # or webrick, mongrel

layout 'layout'

DEBUG = false

$client_credentials = {
  client_id: YAML::load(File.open("creds.yml"))["access"],
  client_secret: YAML::load(File.open("creds.yml"))["secret"] 
}
$callback_url = 'http://localhost:5000'

# Configure the initial application
configure do

  	set :show_exceptions, true

    @@bridge = SpotifyWebBridge.new()

    tracks = @@bridge.get_tracks()


    # TODO: Get the currently playing artist, title

    @@played, @@playing, @@voted, @@other = @@bridge.build_playlists_group_data(artist, title)

    puts "\nGroup Data:"
    puts "Played #{@@played.size()}"
    puts "Playing #{@@playing.size()}"
    puts "Voted #{@@voted.size()}"
    puts "Other #{@@other.size()}"

    @@playlist = @@bridge.playlist()

    if @@playlist.nil?
        puts "Could not talk to api.spotify.com"  
        exit
    else
        puts "Loaded playlist: #{@@playlist.name}"
    end

    # TODO: Current track id
    imageurl = current_track.album.images[1]["url"]
    settings.connections.each { |out| out <<  %Q^data: { "id": "#{current_track.id}", "name": "#{current_track.name}", "imageurl": "#{imageurl}", "artist": "#{current_track.artists[0].name}" }\n\n^}

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

get "/" do
    if session[:user]
        user = RSpotify::User.from_credentials(user[:credentials])
        puts "Hello, #{session[:user][:name]}. You have #{user.playlists.count} playlists"
    else
        client_id = $client_credentials[:client_id]
        scope = 'playlist-modify-public user-read-private'

        "<a href='https://accounts.spotify.com/authorize?client_id=#{client_id}&response_type=code&scope=#{scope}&redirect_uri=#{$callback_url}&show_dialog=true'>Login</a>"
    end
end

get "/login/spotify" do

  credentials = RSpotify.exchange_code(params[:code], $callback_url, $client_credentials)
  user = RSpotify::User.from_credentials(credentials)

  session[:user] = {
    name: user.name,
    credentials: user.credentials
  }

  redirect to("/")
end

get "/playlist" do

    # adapter = SpotifyAdapterLinux.new()
    # @artist, @title = adapter.songinfo()
    # TODO: Get the currently playing artist, title

    puts "Currently playing: #{@artist} - #{@title}"

   	erb :playlist
end

get '/stream', provides: 'text/event-stream' do

    stream :keep_open do |out|        
        puts "Received connection: #{out}"
        settings.connections << out
        out.callback {settings.connections.delete(out)}
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
    
    erb :search
end

post "/search" do
    
    searchtext = params["searchtext"]
    puts "Searching for #{searchtext}"
    
    @searchtracks = @@bridge.search_tracks(searchtext)
    @searchtracks.each do |t|
        puts "Found: #{t.name}"
    end

    erb :search
end

post "/addtrack" do
    
    trackid = params["trackid"]
    puts "Adding: #{trackid}"

    @@bridge.find_track()    
    @@bridge.add_track()

    erb :search
end

# post "/playpause" do

#     adapter = SpotifyAdapterLinux.new()
#     adapter.playpause()    
# end

# post "/next" do

#     adapter = SpotifyAdapterLinux.new()
#     adapter.next()    
# end

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