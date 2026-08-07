module AgentGateway
  module Tools
    # The user's albums as a list, mirroring GET /api/v1/albums.
    class ListAlbums < AgentGateway::Tool
      tool_name "list_albums"
      description "List the user's albums. Filter by title fragment or artist; sortable."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          q: {type: "string", description: "Title fragment filter"},
          artist_id: {type: "integer", description: "Only albums by this artist"},
          sort: {type: "string", enum: Album::SORT_OPTIONS.keys, description: "Default created_at"},
          direction: {type: "string", enum: %w[asc desc], description: "Default desc"},
          limit: {type: "integer", minimum: 1, maximum: 200, description: "Default 100"}
        }
      )

      def self.perform(server_context:, q: nil, artist_id: nil, sort: nil, direction: nil, limit: 100)
        scope = user(server_context).albums.includes(:artist, cover_image_attachment: :blob)
        scope = scope.search(q) if q.present?
        scope = scope.where(artist_id: artist_id) if artist_id.present?
        albums = scope.sort_by_params(sort, direction || "desc").limit(limit.to_i.clamp(1, 200))

        json_response(
          albums: API::V1::AlbumSerializer.render_as_hash(albums, view: :search_result),
          count: albums.size
        )
      end
    end
  end
end
