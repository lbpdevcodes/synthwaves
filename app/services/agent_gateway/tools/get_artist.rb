module AgentGateway
  module Tools
    # One artist with their albums, mirroring GET /api/v1/artists/:id.
    class GetArtist < AgentGateway::Tool
      tool_name "get_artist"
      description "Get one artist by ID, including their albums (newest first)."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          artist_id: {type: "integer"}
        },
        required: ["artist_id"]
      )

      def self.perform(artist_id:, server_context:)
        artist = user(server_context).artists.find(artist_id)
        albums = artist.albums.includes(cover_image_attachment: :blob).order(year: :desc, title: :asc)

        json_response(
          API::V1::ArtistSerializer.render_as_hash(artist, view: :full).merge(
            albums: API::V1::AlbumSerializer.render_as_hash(albums, view: :summary)
          )
        )
      end
    end
  end
end
