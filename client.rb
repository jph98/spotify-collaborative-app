#!/usr/bin/env ruby

require "yaml"
require 'rspotify'

class SpotifyClient

	def initialize(userid, access, secret)
		@userid = userid
		RSpotify.authenticate(access, secret)	
	end

	def display_playlists() 

		user = RSpotify::User.find(@userid)
		return user.playlists
	end

	def display_tracks(playlist_name)

		playlist = ""
		display_playlists().each do |p|

			if p.name.eql? playlist_name
				playlist = p
				break
			end
		end

		puts "Listing playlist: #{playlist.name} [#{playlist.id}]"
		p = RSpotify::Playlist.find(@userid, playlist.id)
		p.tracks.each do |t|
			
			puts "\t - #{t.artists[0].name} - #{t.name}"
		end

	end

	def search_tracks(name)

		tracks = RSpotify::Track.search(name)
		tracks.each do |t|
			puts "Found track: #{t.name} - #{t.artists[0].name}"
		end
	end

	def add_track_to_playlist(p, tracks)

		p.add_tracks(track)
	end
end

yml = YAML::load(File.open("creds.yml"))

client = SpotifyClient.new("jph98", yml["access"], yml["secret"])
client.display_tracks(yml["collab_playlist_name"])

#client.search_tracks("Cannonball")
#client.add_track_to_playlist()