module AgentGateway
  module Tools
    # The user's favorites, mirroring GET /api/v1/favorites.
    class ListFavorites < AgentGateway::Tool
      tool_name "list_favorites"
      description "List the user's favorites, most recent first. Filter to one record type."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          type: {type: "string", enum: %w[Track Album Artist]},
          limit: {type: "integer", minimum: 1, maximum: 200, description: "Default 100"}
        }
      )

      def self.perform(server_context:, type: nil, limit: 100)
        scope = user(server_context).favorites.includes(:favorable).order(created_at: :desc)
        scope = scope.where(favorable_type: type) if type.present?
        favorites = scope.limit(limit.to_i.clamp(1, 200))

        json_response(
          favorites: API::V1::FavoriteSerializer.render_as_hash(favorites),
          count: favorites.size
        )
      end
    end
  end
end
