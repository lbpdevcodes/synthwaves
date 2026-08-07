module AgentGateway
  module Tools
    # The user's playlists as a list, mirroring GET /api/v1/playlists.
    class ListPlaylists < AgentGateway::Tool
      tool_name "list_playlists"
      description "List the user's playlists with track counts. Filter by name fragment; sortable."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          q: {type: "string", description: "Name fragment filter"},
          sort: {type: "string", enum: Playlist::SORT_OPTIONS.keys, description: "Default created_at"},
          direction: {type: "string", enum: %w[asc desc], description: "Default desc"},
          limit: {type: "integer", minimum: 1, maximum: 200, description: "Default 100"}
        }
      )

      def self.perform(server_context:, q: nil, sort: nil, direction: nil, limit: 100)
        scope = user(server_context).playlists
        scope = scope.search(q) if q.present?
        playlists = scope.sort_by_params(sort, direction || "desc").limit(limit.to_i.clamp(1, 200))

        json_response(
          playlists: API::V1::PlaylistSerializer.render_as_hash(playlists, view: :full),
          count: playlists.size
        )
      end
    end
  end
end
