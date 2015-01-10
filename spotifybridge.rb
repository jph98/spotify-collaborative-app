#!/usr/bin/env ruby

require "yaml"
require 'rspotify'

class SpotifyBridge

	attr_accessor :playlist, :userid

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

		puts "Listing playlistname: #{@playlist.name} [#{@playlist.id}]"
		p = RSpotify::Playlist.find(@userid, @playlist.id)
		p.tracks.each do |t|

			#OpenStruct.new(t, 0)
			puts "\t - #{t.artists[0].name} - #{t.name} - #{t.uri} - #{t.external_ids} - #{t.explicit} - #{t.popularity}"
		end

		return p.tracks

	end

	def search_tracks(name)

		tracks = RSpotify::Track.search(name)
		tracks.each do |t|
			puts "Found track: #{t.name} - #{t.artists[0].name} - #{t.preview_url}"
		end
	end

	def add_track_to_playlist(p, tracks)

		p.add_tracks(track)
	end
end

if __FILE__ == $0

	sb = SpotifyBridge.new()
	tracks = sb.get_tracks()
	puts tracks
end