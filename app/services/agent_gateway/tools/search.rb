module AgentGateway
  module Tools
    # Unified artist/album/track search, mirroring GET /api/v1/search.
    class Search < AgentGateway::Tool
      tool_name "search"
      description "Search the user's library across artists, albums, and tracks by title/name fragment. " \
        "Supports filtering by genre, year range, category, tags, or favorites only."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          query: {type: "string", description: "Title/name fragment to match"},
          types: {type: "array", items: {type: "string", enum: %w[artist album track]},
                  description: "Record types to search; defaults to all"},
          limit: {type: "integer", minimum: 1, maximum: 50, description: "Per-type result cap, default 20"},
          genre: {type: "string"},
          year_from: {type: "integer"},
          year_to: {type: "integer"},
          favorites_only: {type: "boolean", description: "Only return favorited records"},
          category: {type: "string", enum: %w[music podcast], description: "Default music"},
          tags: {type: "array", items: {type: "string"}, description: "Filter tracks by tag names"}
        },
        required: ["query"]
      )

      def self.perform(query:, server_context:, types: nil, limit: 20, genre: nil, year_from: nil,
        year_to: nil, favorites_only: false, category: nil, tags: nil)
        results = SearchService.call(
          query: query,
          types: types ? types.map(&:to_sym) & %i[artist album track] : %i[artist album track],
          limit: limit.to_i.clamp(1, 50),
          genre: genre,
          year_from: year_from,
          year_to: year_to,
          favorites_only: favorites_only,
          category: category,
          tags: tags,
          user: user(server_context)
        )

        json_response(
          artists: API::V1::ArtistSerializer.render_as_hash(results[:artists], view: :summary),
          albums: API::V1::AlbumSerializer.render_as_hash(results[:albums], view: :search_result),
          tracks: API::V1::TrackSerializer.render_as_hash(results[:tracks], view: :embedded)
        )
      end
    end
  end
end
