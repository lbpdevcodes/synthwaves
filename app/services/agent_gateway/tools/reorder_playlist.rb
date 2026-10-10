module AgentGateway
  module Tools
    # Rewrites a playlist's track order, mirroring
    # PUT /api/v1/playlists/:id/track_order. Both go through Playlist#reorder!.
    class ReorderPlaylist < AgentGateway::Tool
      tool_name "reorder_playlist"
      description "Set the full track order of a playlist. Pass every playlist_track_id (from " \
        "get_playlist) in the desired order. Unknown IDs are ignored."
      annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)
      input_schema(
        properties: {
          playlist_id: {type: "integer"},
          playlist_track_ids: {type: "array", items: {type: "integer"}, minItems: 1}
        },
        required: ["playlist_id", "playlist_track_ids"]
      )

      def self.perform(playlist_id:, playlist_track_ids:, server_context:)
        playlist = user(server_context).playlists.find(playlist_id)

        playlist.reorder!(playlist_track_ids)

        json_response(reordered: playlist_track_ids.size)
      end
    end
  end
end
