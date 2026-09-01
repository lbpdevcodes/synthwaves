module AgentGateway
  module Tools
    # Adds tracks to a playlist, mirroring POST /api/v1/playlists/:id/tracks.
    class AddTracksToPlaylist < AgentGateway::Tool
      tool_name "add_tracks_to_playlist"
      description "Add tracks to a playlist, either by track_ids (added in the given order) or by " \
        "album_id (adds the album's tracks in disc/track order). Pass exactly one. " \
        "Duplicates already in the playlist are skipped. Send at most 500 track_ids per call — " \
        "split a longer list and call again, because appends accumulate."
      annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)
      input_schema(
        properties: {
          playlist_id: {type: "integer"},
          track_ids: {type: "array", items: {type: "integer"}, minItems: 1,
                      description: "Tracks to append, in order; at most 500 per call"},
          album_id: {type: "integer"}
        },
        required: ["playlist_id"]
      )

      def self.perform(playlist_id:, server_context:, track_ids: nil, album_id: nil)
        if track_ids.present? == album_id.present?
          return error_response("Pass exactly one of track_ids or album_id")
        end

        limit_error = bulk_limit_error(track_ids)
        return limit_error if limit_error

        playlist = user(server_context).playlists.find(playlist_id)
        added = if track_ids.present?
          playlist.add_tracks(ordered_tracks(user(server_context), track_ids))
        else
          album = user(server_context).albums.find(album_id)
          playlist.add_tracks(album.tracks.order(:disc_number, :track_number))
        end

        json_response(added: added, tracks_count: playlist.reload.playlist_tracks_count)
      end

      def self.ordered_tracks(user, track_ids)
        tracks = user.tracks.where(id: track_ids)
        track_ids.filter_map { |id| tracks.find { |track| track.id == id } }
      end
    end
  end
end
