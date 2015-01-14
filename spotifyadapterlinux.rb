#!/usr/bin/env ruby

require "yaml"

# Local adapter that makes use of MPRIS2 DBUS to communicate with a local spotify
# This provides functionality that the web API doesn't
class SpotifyAdapterLinux

	DEBUG = false
	PREFIX = "dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2"

	def play() 
		`#{PREFIX} org.mpris.MediaPlayer2.Player.Play`
	end

	def pause()
		`#{PREFIX} org.mpris.MediaPlayer2.Player.Pause`
	end

	def get_metadata()
		return `dbus-send --print-reply --session --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get string:'org.mpris.MediaPlayer2.Player' string:'Metadata'`
	end

	def songinfo()

		metadata = get_metadata()

		metadata = metadata.delete("\n")
		
		puts metadata if DEBUG

		if metadata.nil? or metadata.eql? ""
			puts "Could not communicate with local Spotify instance"
			exit
		end

		# TODO: Handle dashes etc in title and artist
		#matches = metadata.match(/xesam\:title\"[\sa-z]+\"([\w\s]+)\"/)
		matches = metadata.match(/xesam\:title\"[\sa-z]+\"([\w\s-]+)\"/)
		title = matches[1]

		matches = metadata.match(/xesam\:artist\"[a-z\s\[\"]+([\w\s]+)/)
		artist = matches[1]

		puts "Artist: #{artist} - #{title}"

		return artist, title
	end
end

if __FILE__ == $0

	sa = SpotifyAdapterLinux.new()
	sa.get_current_song()
end