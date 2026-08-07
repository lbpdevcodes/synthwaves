module AgentGateway
  module Tools
    # Rewrites a playlist's track order, mirroring
    # PUT /api/v1/playlists/:id/track_order. The two-pass negative-position
    # transaction avoids unique-index collisions on [playlist_id, position].
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

        ActiveRecord::Base.transaction do
          playlist_track_ids.each_with_index do |id, index|
            playlist.playlist_tracks.where(id: id).update_all(position: -(index + 1))
          end
          playlist_track_ids.each_with_index do |id, index|
            playlist.playlist_tracks.where(id: id).update_all(position: index + 1)
          end
        end

        json_response(reordered: playlist_track_ids.size)
      end
    end
  end
end
