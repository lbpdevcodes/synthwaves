module AgentGateway
  module Tools
    # One playlist with its tracks. The default is the full unpaginated
    # payload; compact and page/per_page keep large playlists token-lean.
    class GetPlaylist < AgentGateway::Tool
      tool_name "get_playlist"
      description "Get one playlist by ID with its tracks in position order. Each entry carries a " \
        "playlist_track_id — pass that (not the track ID) to remove_playlist_track(s) and reorder_playlist. " \
        "Large playlists: pass compact=true and page/per_page to avoid huge payloads; without page the " \
        "full playlist is returned."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          playlist_id: {type: "integer"},
          compact: {
            type: "boolean",
            description: "Flat per-track rows (position, playlist_track_id, track_id, title, artist, " \
              "duration) instead of the full embedded track payload. Strongly recommended for large playlists."
          },
          page: {
            type: "integer",
            minimum: 1,
            description: "Return one page of tracks; omit to return the whole playlist"
          },
          per_page: {
            type: "integer",
            minimum: 1,
            maximum: 500,
            description: "Tracks per page (default 50 when page is given, max 500)"
          }
        },
        required: ["playlist_id"]
      )

      def self.perform(playlist_id:, server_context:, compact: false, page: nil, per_page: nil)
        playlist = user(server_context).playlists.find(playlist_id)
        scope = playlist.playlist_tracks.includes(track: [:artist, :album]).order(:position)

        json_response(payload_for(playlist, scope, compact, page, per_page))
      end

      def self.payload_for(playlist, scope, compact, page, per_page)
        payload = API::V1::PlaylistSerializer.render_as_hash(playlist, view: :full)
        payload[:total_duration] = playlist.tracks.sum(:duration)
        return payload.merge(tracks: render_tracks(scope, compact)) unless page || per_page

        payload.merge(paged_payload(scope, compact, page, per_page))
      end
      private_class_method :payload_for

      def self.paged_payload(scope, compact, page, per_page)
        page = (page || 1).to_i
        per_page = (per_page || 50).to_i
        {
          tracks: render_tracks(scope.offset((page - 1) * per_page).limit(per_page), compact),
          pagination: pagination_meta(page, per_page, scope.count)
        }
      end
      private_class_method :paged_payload

      # Same meta shape as the REST v1 API.
      def self.pagination_meta(page, per_page, total_count)
        {
          page: page,
          per_page: per_page,
          total_pages: (total_count.to_f / per_page).ceil,
          total_count: total_count
        }
      end
      private_class_method :pagination_meta

      def self.render_tracks(scope, compact)
        if compact
          API::V1::PlaylistTrackSerializer.render_as_hash(scope, view: :compact)
        else
          API::V1::PlaylistTrackSerializer.render_as_hash(scope, view: :full)
        end
      end
      private_class_method :render_tracks
    end
  end
end
