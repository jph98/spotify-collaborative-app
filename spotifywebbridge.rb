#!/usr/bin/env ruby

require "yaml"
require 'rspotify'
require_relative 'spotifyadapterlinux'

class SpotifyWebBridge

	attr_accessor :playlist, :userid

	DEBUG = false

	def initialize()

		yml = YAML::load(File.open("creds.yml"))
		@userid = yml["userid"]
		@playlistname = yml["collab_playlist_name"]
		RSpotify.authenticate(yml["access"], yml["secret"])	
	end

	def get_user()
		return RSpotify::User.find(@userid)		
	end

	# See - https://github.com/guilhermesad/rspotify/blob/master/lib/rspotify/user.rb
	def get_playlists() 

		# TODO: List ALL the playlists
		puts "Get #{@userid}"
		@user = RSpotify::User.find(@userid)

		offset = 0
		playlists = @user.playlists(limit: 50, offset: offset)
		while true			
			offset += 50
			more = @user.playlists(limit: 50, offset: offset)
			puts "Found more... #{offset} #{more.size}"
			if more.size.eql? 0 
				break
			else
				playlists << more
			end
		end

		puts "Found: #{playlists.size}"

		return playlists
	end

	def get_playlist() 

		puts "Get playlist for name #{@playlistname}"
		get_playlists().each do |p|

			puts "Name: #{p.id} #{p.name}"

			if p.name.eql? @playlistname
				puts "Found playlist #{@playlistname}"
				return p
			end
		end
	end

	# See - https://github.com/guilhermesad/rspotify/blob/master/lib/rspotify/track.rb
	def get_tracks()

		track_votes = {}

		if @playlist.nil?
			@playlist = get_playlist()		
		end

		puts "\nListing playlistname: #{@playlist.name} [#{@playlist.id}]" if DEBUG

		return @playlist.tracks

	end

	def build_playlists_group_data(artist, title)

		found_currently_playing = false
		playing = nil
		voted = {}
		other = {}
		played = {}

		trackinfo = @playlist.tracks

		trackinfo.each do |t|

			track = build_track_metadata(t)

			if track.artist.eql? artist and t.name.eql? title

				playing = track
				found_currently_playing = true
				puts "\tPLAYING: #{track.artist} #{track.name}"
				next

			elsif found_currently_playing and track.votes.size() > 0

				puts "\tVOTED: #{track.artist} #{track.name}"
				voted[track.id] = track
			elsif found_currently_playing

				puts "\tOTHER: #{track.artist} #{track.name}"
				other[track.id] = track
				puts "Other size: #{other.size()} - #{track.id}"
			else

				played[track.id] = track
				puts "\tPLAYED: #{track.artist} #{track.name}"
			end
		end

		return played, playing, voted, other
	end

	def get_preview_image(images)

	    return images[2]
	end 

	def get_fullsize_image(images)

	    return images[1]
	end

	def build_track_metadata(t)

		return OpenStruct.new(:id => t.id,
							  :name => t.name,
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

	def search_tracks(name)

		tracks = RSpotify::Track.search(name)
		tracks.each do |t|
			puts "Found track: #{t.name} - #{t.artists[0].name} - #{t.preview_url}" if DEBUG
		end
	end

	def find_track_in_playlist(id)

		@playlist.tracks.each do |t|
			if t.id.eql? id
				return t
			end
		end
	end

	def find_track_by_artist_title(artist, title)

		@playlist.tracks.each do |t|

			if t.artists[0].name.eql? artist and t.name.eql? title
				return t
			end
		end
	end

	# https://github.com/guilhermesad/rspotify/blob/master/lib/rspotify/playlist.rb
	def store_tracks(tracks)

		new_tracks = []

		yml = YAML::load(File.open("creds.yml"))
		@userid = yml["userid"]
		@playlistname = yml["collab_playlist_name"]
		RSpotify.authenticate(yml["access"], yml["secret"])	

		# puts "User creds: #{@user.class_variable_get('@@users_credentials')}"

		# Grab existing tracks for the Spotify playlist

		@playlist.tracks.each do |k|
			puts "Spotify Track: #{k.id} #{k.name} #{k.artists[0].name}"
		end

		puts "\n"

		# List the App playlist
		tracks.each_key do |k|
			puts "App Track: #{tracks[k].id} #{tracks[k].name} #{tracks[k].artist} #{tracks[k].votes.size()}"
		end

		puts "\n"

		# Map the "App playlist" over to the "Spotify Playlist"
		tracks.each_key do |k|
			puts "Trying to find by id: #{tracks[k].id} #{tracks[k].name} #{tracks[k].artist} #{tracks[k].votes.size()}"
			track = find_track_in_playlist(tracks[k].id)
			puts "\tFound #{track.id} - #{track.name}"
			new_tracks << track
		end		

		new_tracks.each do |nt|
			puts "New Track: #{nt.id} - #{nt.name} - #{nt.uri}"
		end

		puts "Display Name: #{@user.display_name}"

		# Store new playlist		

		# Need to follow this - https://developer.spotify.com/web-api/authorization-guide/#authorization_code_flow

		# Add local and remote
		@playlist.add_tracks!(new_tracks)

		# TODO: Persist the playlist locally instead of using application wide variables
	end

end

if __FILE__ == $0

	sb = SpotifyWebBridge.new()
	tracks = sb.get_tracks()
	puts tracks
end