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

	def get_playlists() 

		puts "Get playlist for #{@userid}"
		user = RSpotify::User.find(@userid)
		return user.playlists
	end

	def get_playlist() 

		get_playlists().each do |p|

			if p.name.eql? @playlistname
				return p
			end
		end
	end

	# See - https://github.com/guilhermesad/rspotify/blob/master/lib/rspotify/track.rb
	def get_tracks()

		track_votes = {}

		@playlist = get_playlist()

		puts "Listing playlistname: #{@playlist.name} [#{@playlist.id}]" if DEBUG
		p = RSpotify::Playlist.find(@userid, @playlist.id)
		p.tracks.each do |t|
			puts "\t - #{t.artists[0].name} - #{t.name} - #{t.uri} - #{t.external_ids} - #{t.explicit} - #{t.popularity}" if DEBUG
		end

		return p.tracks

	end

	def get_track_groups(artist, title)

		p = RSpotify::Playlist.find(@userid, @playlist.id)
		found_currently_playing = false
		playing = ""
		voted = {}
		other = {}
		played = {}

		trackinfo = p.tracks

		trackinfo.each do |t|

			track = build_track(t)

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

	def build_track(t)

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

	# https://github.com/guilhermesad/rspotify/blob/master/lib/rspotify/playlist.rb
	def store_tracks(tracks)

		# TODO: Just move id's around
		# TODO: Fix the URI issue
		new_tracks = []
		playlist = RSpotify::Playlist.find(@userid, @playlist.id)
		playlist.tracks.each do |k|
			puts "Spotify Track: #{k.id} #{k.name} #{k.artists[0].name}"
		end

		tracks.each_key do |k|
			puts "Trying to find by id: #{tracks[k].id} #{tracks[k].name} #{tracks[k].artist} #{tracks[k].votes.size()}"
			# track = RSpotify::Track.search()
			track = playlist.tracks.find(tracks[k].id)
			new_tracks = track
		end		
		playlist.replace_tracks!(new_tracks)
	end
end

if __FILE__ == $0

	sb = SpotifyWebBridge.new()
	tracks = sb.get_tracks()
	puts tracks
end