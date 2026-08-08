module AgentGateway
  module Tools
    # One playlist with its tracks, mirroring GET /api/v1/playlists/:id
    # (unpaginated — large playlists return large payloads).
    class GetPlaylist < AgentGateway::Tool
      tool_name "get_playlist"
      description "Get one playlist by ID with its tracks in position order. Each entry carries a " \
        "playlist_track_id — pass that (not the track ID) to remove_playlist_track and reorder_playlist. " \
        "Not paginated: large playlists return large payloads."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          playlist_id: {type: "integer"}
        },
        required: ["playlist_id"]
      )

      def self.perform(playlist_id:, server_context:)
        playlist = user(server_context).playlists.find(playlist_id)
        playlist_tracks = playlist.playlist_tracks.includes(track: [:artist, :album]).order(:position)

        json_response(
          API::V1::PlaylistSerializer.render_as_hash(playlist, view: :full).merge(
            total_duration: playlist.tracks.sum(:duration),
            tracks: API::V1::PlaylistTrackSerializer.render_as_hash(playlist_tracks)
          )
        )
      end
    end
  end
end
