module AgentGateway
  module Tools
    # Edits an album in place, mirroring PATCH /api/v1/albums/:id, with the
    # artist given by name rather than id.
    class UpdateAlbum < AgentGateway::Tool
      tool_name "update_album"
      description "Edit an album: its title, year, genre, or the artist it belongs to. The " \
        "artist is given by NAME, not id, and is matched case-insensitively, so \"caifanes\" " \
        "joins an existing \"CAIFANES\"; a name the library does not hold is created. " \
        "WARNING: changing the artist moves EVERY TRACK on the album to that artist too, not " \
        "just the album row — one call can move a whole tracklist. Use it to repair an import " \
        "that filed a real album under the uploader's channel. Titles must be unique within " \
        "an artist, so retitling onto a title that artist already has is refused."
      annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true)
      input_schema(
        properties: {
          album_id: {type: "integer"},
          title: {type: "string"},
          year: {type: "integer"},
          genre: {type: "string"},
          artist: {type: "string", description: "Artist name, not id. Moves the album's tracks too."}
        },
        required: ["album_id"]
      )

      def self.perform(album_id:, server_context:, title: nil, year: nil, genre: nil, artist: nil)
        scalars = {title: title, year: year, genre: genre}.compact
        if scalars.empty? && artist.nil?
          return error_response("Name at least one of title, year, genre or artist.")
        end

        album = user(server_context).albums.find(album_id)

        # One transaction so a rejected album update also rolls back an artist
        # this call created for it.
        ActiveRecord::Base.transaction do
          album.update!(scalars.merge(artist_changes(album, artist)))
        end

        json_response(API::V1::AlbumSerializer.render_as_hash(album, view: :full))
      end

      def self.artist_changes(album, name)
        return {} if name.nil?

        {artist: Artist.find_or_create_named!(album.user, name)}
      end
      private_class_method :artist_changes
    end
  end
end
