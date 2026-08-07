module AgentGateway
  module Tools
    # Creates a playlist from an album, mirroring POST /albums/:id/create_playlist.
    class CreatePlaylistFromAlbum < AgentGateway::Tool
      tool_name "create_playlist_from_album"
      description "Create a playlist containing every track of an album (in disc/track order). " \
        "The playlist is named after the album unless name is given."
      annotations(read_only_hint: false, destructive_hint: false)
      input_schema(
        properties: {
          album_id: {type: "integer"},
          name: {type: "string", description: "Playlist name; defaults to the album title"}
        },
        required: ["album_id"]
      )

      def self.perform(album_id:, server_context:, name: nil)
        album = user(server_context).albums.find(album_id)
        playlist = user(server_context).playlists.create!(name: name.presence || album.title)
        added = playlist.add_tracks(album.tracks.order(:disc_number, :track_number))

        json_response(API::V1::PlaylistSerializer.render_as_hash(playlist, view: :full).merge(added: added))
      end
    end
  end
end
