module AgentGateway
  module Tools
    # Bulk counterpart of remove_playlist_track. delete_all skips counter_cache
    # callbacks, so reset_counters repairs the count in the same transaction.
    class RemovePlaylistTracks < AgentGateway::Tool
      tool_name "remove_playlist_tracks"
      description "Remove many entries from a playlist in one call. Pass exactly one of " \
        "playlist_track_ids (entry IDs from get_playlist — NOT track IDs) or track_ids (removes " \
        "every entry with those track IDs, including duplicates). Unknown IDs are ignored. " \
        "The tracks themselves stay in the library."
      annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true)
      input_schema(
        properties: {
          playlist_id: {type: "integer"},
          playlist_track_ids: {type: "array", items: {type: "integer"}, minItems: 1, maxItems: 10_000},
          track_ids: {type: "array", items: {type: "integer"}, minItems: 1, maxItems: 10_000}
        },
        required: ["playlist_id"]
      )

      def self.perform(playlist_id:, server_context:, playlist_track_ids: nil, track_ids: nil)
        if playlist_track_ids.present? == track_ids.present?
          return error_response("Pass exactly one of playlist_track_ids or track_ids")
        end

        playlist = user(server_context).playlists.find(playlist_id)
        scope = playlist.playlist_tracks
        scope = playlist_track_ids.present? ? scope.where(id: playlist_track_ids) : scope.where(track_id: track_ids)

        removed = 0
        ActiveRecord::Base.transaction do
          removed = scope.delete_all
          Playlist.reset_counters(playlist.id, :playlist_tracks)
        end

        json_response(removed: removed, tracks_count: playlist.reload.playlist_tracks_count)
      end
    end
  end
end
