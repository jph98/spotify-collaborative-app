spotify-collaborative-app
=========================

Web Based Company Collaborative Playlist Manager for Spotify

Makes use of rspotify for managing playlists. Needs Ruby > 2.0

Uses a local Spotify instance to fill in the gaps for the web API, mainly controlling playback, retrieving current song.  

Currently only a Linux adapter is provided.

When loading:
* Highlight the current song playing
* Make the songs before this non-clickable

When a user votes:
* Grab the current song playing
* Manage all songs after this in terms of IP address and number of votes

Play, Pause buttons on the web interface

Album art for each of the songs displayed:
* https://github.com/guilhermesad/rspotify/blob/master/lib/rspotify/album.rb