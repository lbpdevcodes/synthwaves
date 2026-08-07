module AgentGateway
  module Tools
    # One album with its tracks, mirroring GET /api/v1/albums/:id.
    class GetAlbum < AgentGateway::Tool
      tool_name "get_album"
      description "Get one album by ID, including its tracks in disc/track order and total duration in seconds."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          album_id: {type: "integer"}
        },
        required: ["album_id"]
      )

      def self.perform(album_id:, server_context:)
        album = user(server_context).albums.find(album_id)
        tracks = album.tracks.order(disc_number: :asc, track_number: :asc)

        json_response(
          API::V1::AlbumSerializer.render_as_hash(album, view: :full).merge(
            total_duration: tracks.sum(:duration),
            tracks: API::V1::TrackSerializer.render_as_hash(tracks, view: :summary)
          )
        )
      end
    end
  end
end
