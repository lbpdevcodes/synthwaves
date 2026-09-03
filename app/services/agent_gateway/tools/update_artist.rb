module AgentGateway
  module Tools
    # Renames an artist in place, mirroring PATCH /api/v1/artists/:id.
    class UpdateArtist < AgentGateway::Tool
      tool_name "update_artist"
      description "Rename an artist, or change whether it is music or a podcast. Renaming " \
        "rewrites the name on the artist itself; every track and album keeps pointing at it, " \
        "and the search index follows. Use this to fix a misspelling or an accent " \
        "(\"Mana\" to \"Maná\"). It does NOT merge: renaming onto a name the library already " \
        "holds is refused, because two artists cannot share a name. To move one artist's " \
        "tracks onto another, retag the tracks with update_tracks instead."
      annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true)
      input_schema(
        properties: {
          artist_id: {type: "integer"},
          name: {type: "string"},
          category: {type: "string", enum: Artist::CATEGORIES}
        },
        required: ["artist_id"]
      )

      def self.perform(artist_id:, server_context:, name: nil, category: nil)
        changes = {name: name, category: category}.compact
        return error_response("Name at least one of name or category.") if changes.empty?

        artist = user(server_context).artists.find(artist_id)
        artist.update!(changes)

        json_response(API::V1::ArtistSerializer.render_as_hash(artist, view: :full))
      end
    end
  end
end
