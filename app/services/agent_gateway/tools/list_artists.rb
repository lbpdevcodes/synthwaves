module AgentGateway
  module Tools
    # The user's artists as a list, mirroring GET /api/v1/artists.
    class ListArtists < AgentGateway::Tool
      tool_name "list_artists"
      description "List the user's artists. Filter by name fragment or category; sortable."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          q: {type: "string", description: "Name fragment filter"},
          category: {type: "string", enum: %w[music podcast]},
          sort: {type: "string", enum: Artist::SORT_OPTIONS.keys, description: "Default created_at"},
          direction: {type: "string", enum: %w[asc desc], description: "Default desc"},
          limit: {type: "integer", minimum: 1, maximum: 200, description: "Default 100"}
        }
      )

      def self.perform(server_context:, q: nil, category: nil, sort: nil, direction: nil, limit: 100)
        scope = user(server_context).artists
        scope = scope.search(q) if q.present?
        scope = scope.where(category: category) if category.present?
        artists = scope.sort_by_params(sort, direction || "desc").limit(limit.to_i.clamp(1, 200))

        json_response(
          artists: API::V1::ArtistSerializer.render_as_hash(artists, view: :summary),
          count: artists.size
        )
      end
    end
  end
end
