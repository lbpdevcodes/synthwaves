module AgentGateway
  module Tools
    # Creates a playlist, mirroring POST /api/v1/playlists.
    class CreatePlaylist < AgentGateway::Tool
      tool_name "create_playlist"
      description "Create a playlist. Optionally seed it with track_ids, added in the given order. " \
        "Use search or list_tracks to find track IDs first."
      annotations(read_only_hint: false, destructive_hint: false)
      input_schema(
        properties: {
          name: {type: "string"},
          track_ids: {type: "array", items: {type: "integer"},
                      description: "Tracks to add, in the given order; unknown IDs are skipped"}
        },
        required: ["name"]
      )

      def self.perform(name:, server_context:, track_ids: nil)
        playlist = user(server_context).playlists.build(name: name)
        return error_response(playlist.errors.full_messages.join(", ")) unless playlist.save

        added = add_tracks_in_order(playlist, user(server_context), track_ids)
        json_response(API::V1::PlaylistSerializer.render_as_hash(playlist, view: :full).merge(added: added))
      end

      def self.add_tracks_in_order(playlist, user, track_ids)
        return 0 if track_ids.blank?

        tracks = user.tracks.where(id: track_ids)
        ordered = track_ids.filter_map { |id| tracks.find { |track| track.id == id } }
        playlist.add_tracks(ordered)
      end
    end
  end
end
