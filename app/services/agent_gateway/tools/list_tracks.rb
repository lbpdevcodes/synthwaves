module AgentGateway
  module Tools
    # The user's tracks as a list, mirroring GET /api/v1/tracks.
    class ListTracks < AgentGateway::Tool
      tool_name "list_tracks"
      description "List the user's tracks. Filter by title fragment (full-text), album, artist, or genre; sortable."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          q: {type: "string", description: "Title fragment filter (full-text search)"},
          album_id: {type: "integer"},
          artist_id: {type: "integer"},
          genre: {type: "string"},
          sort: {type: "string", enum: Track::SORT_OPTIONS.keys, description: "Default created_at"},
          direction: {type: "string", enum: %w[asc desc], description: "Default desc"},
          limit: {type: "integer", minimum: 1, maximum: 100, description: "Default 50"}
        }
      )

      def self.perform(server_context:, q: nil, album_id: nil, artist_id: nil, genre: nil,
        sort: nil, direction: nil, limit: 50)
        scope = user(server_context).tracks.includes(:artist, :album)
        scope = scope.search(q) if q.present?
        scope = scope.where(album_id: album_id) if album_id.present?
        scope = scope.where(artist_id: artist_id) if artist_id.present?
        scope = scope.by_genre(genre) if genre.present?
        tracks = scope.sort_by_params(sort, direction || "desc").limit(limit.to_i.clamp(1, 100))

        json_response(
          tracks: API::V1::TrackSerializer.render_as_hash(tracks, view: :embedded),
          count: tracks.size
        )
      end
    end
  end
end
