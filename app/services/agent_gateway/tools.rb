module AgentGateway
  # The curated MCP surface: the high-value library operations an agent
  # needs, not full REST parity.
  module Tools
    ALL = [
      Search, MatchTracks,
      ListArtists, GetArtist, UpdateArtist,
      ListAlbums, GetAlbum, UpdateAlbum,
      ListTracks, GetTrack, UpdateTracks,
      ListPlaylists, GetPlaylist,
      ListFavorites,
      CreatePlaylist, UpdatePlaylist, DeletePlaylist,
      AddTracksToPlaylist, RemovePlaylistTrack, RemovePlaylistTracks,
      ReorderPlaylist,
      CreatePlaylistFromAlbum,
      Favorite, Unfavorite,
      UploadTrack, ImportYoutubePlaylist
    ].freeze
  end
end
