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

	def search_tracks(name)

		tracks = RSpotify::Track.search(name)
		tracks.each do |t|
			puts "Found track: #{t.name} - #{t.artists[0].name} - #{t.preview_url}" if DEBUG
		end
	end

	def reorder_tracks(trackinfo)

		# Get the track currently playing
		# Get all tracks after this, order by votes
		# Store back into the playlist (entire) or look at API to move
		adapter = SpotifyAdapterLinux.new()
		artist, title = adapter.songinfo()

		found_currently_playing = false
		tracks_played = {}
		tracks_to_reorder = {}

		trackinfo.each_key do |k|

			puts "Track artist: #{trackinfo[k].artist} #{trackinfo[k].name} - #{trackinfo[k].votes.size()}"
			if trackinfo[k].artist.eql? artist and trackinfo[k].name.eql? title

				tracks_played[k] = trackinfo[k]
				found_currently_playing = true
				puts "\tPLAYING: #{trackinfo[k].artist} #{trackinfo[k].name} - #{trackinfo[k].votes.size()}"
				next
			elsif found_currently_playing
				puts "\tREORDER: #{trackinfo[k].artist} #{trackinfo[k].name} - #{trackinfo[k].votes.size()}"
				tracks_to_reorder[k] = trackinfo[k]
			else
				tracks_played[k] = trackinfo[k]
				puts "\tPLAYED: #{trackinfo[k].artist} #{trackinfo[k].name} - #{trackinfo[k].votes.size()}"
			end
		end

		puts "\n\n"

		puts "\nTracks To Reorder: #{tracks_to_reorder.size()}"
		tracks_to_reorder = tracks_to_reorder.sort_by { |k,v| v.votes.size() }.reverse

		new_tracks = {}
		
		# Store the old tracks in the playlist in the order they were
		tracks_played.each_key do |k|
			new_tracks[k] = tracks_played[k]
		end

		# TODO: Only reorder the track that's been voted
		tracks_to_reorder.each do |t|
			id = t[0]
			obj = t[1]
			new_tracks[id] = obj
		end

		new_tracks.each_key do |k|
			puts "Track: #{k} - #{new_tracks[k].artist} - #{new_tracks[k].name} #{new_tracks[k].votes}"
		end

		# Store this back into Spotify
	end
end

if __FILE__ == $0

	sb = SpotifyWebBridge.new()
	tracks = sb.get_tracks()
	puts tracks
end