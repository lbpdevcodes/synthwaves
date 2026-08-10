module AgentGateway
  module Tools
    # Sets a playlist's exact contents in one call. Subsonic's create_playlist
    # full-replace is the prior art; here unknown IDs fail fast so the caller
    # never silently loses tracks.
    class ReplacePlaylistTracks < AgentGateway::Tool
      tool_name "replace_playlist_tracks"
      description "Set the exact full contents of a playlist from an ordered track_ids array. " \
        "Duplicates are allowed; an empty array clears the playlist. Unlike add_tracks_to_playlist " \
        "nothing is skipped — after the call the playlist contains exactly these tracks in this " \
        "order. All playlist_track_id values change, so re-fetch with get_playlist before calling " \
        "remove_playlist_track(s) or reorder_playlist. Fails without changes if any track ID is unknown."
      annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true)
      input_schema(
        properties: {
          playlist_id: {type: "integer"},
          track_ids: {
            type: "array",
            items: {type: "integer"},
            maxItems: 10_000,
            description: "Ordered exact contents; empty array clears the playlist"
          }
        },
        required: ["playlist_id", "track_ids"]
      )

      def self.perform(playlist_id:, track_ids:, server_context:)
        current_user = user(server_context)
        playlist = current_user.playlists.find(playlist_id)

        unknown = unknown_track_ids(current_user, track_ids)
        return error_response("Unknown track IDs: #{unknown.first(10).join(", ")}") if unknown.any?

        playlist.replace_tracks(track_ids)

        json_response(tracks_count: playlist.reload.playlist_tracks_count)
      end

      # where(id:) dedupes, so uniq both sides or intentional duplicates
      # false-positive as unknown.
      def self.unknown_track_ids(current_user, track_ids)
        known = current_user.tracks.where(id: track_ids.uniq).pluck(:id)
        track_ids.uniq - known
      end
    end
  end
end
