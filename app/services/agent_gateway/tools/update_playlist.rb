module AgentGateway
  module Tools
    # Renames a playlist, mirroring PATCH /api/v1/playlists/:id.
    class UpdatePlaylist < AgentGateway::Tool
      tool_name "update_playlist"
      description "Rename a playlist."
      annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)
      input_schema(
        properties: {
          playlist_id: {type: "integer"},
          name: {type: "string"}
        },
        required: ["playlist_id", "name"]
      )

      def self.perform(playlist_id:, name:, server_context:)
        playlist = user(server_context).playlists.find(playlist_id)
        return error_response(playlist.errors.full_messages.join(", ")) unless playlist.update(name: name)

        json_response(API::V1::PlaylistSerializer.render_as_hash(playlist, view: :full))
      end
    end
  end
end
