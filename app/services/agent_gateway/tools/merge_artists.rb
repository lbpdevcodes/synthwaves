module AgentGateway
  module Tools
    # Folds one artist into another. The write counterpart to update_artist,
    # which refuses a rename onto a name the library already holds.
    class MergeArtists < AgentGateway::Tool
      tool_name "merge_artists"
      description "Fold one artist into another and DELETE the source. Use this for a genuine " \
        "duplicate the library holds twice — \"Mana\" beside \"Maná\" — which update_artist " \
        "cannot fix, because renaming onto a name already in use is refused. The source's " \
        "albums, tracks and favorites move to the target; an album whose title the target " \
        "already uses is folded into that copy rather than duplicated. Takes IDs, never names: " \
        "look both artists up first, because this CANNOT BE UNDONE. The reply says how many " \
        "albums and tracks moved."
      annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: false)
      input_schema(
        properties: {
          target_artist_id: {type: "integer", description: "The artist that survives"},
          source_artist_id: {type: "integer", description: "The artist absorbed, then deleted"}
        },
        required: ["target_artist_id", "source_artist_id"]
      )

      def self.perform(target_artist_id:, source_artist_id:, server_context:)
        artists = user(server_context).artists
        target = artists.find(target_artist_id)
        source = artists.find(source_artist_id)
        absorbed = {absorbed_albums: source.albums.count, absorbed_tracks: source.tracks.count}

        ArtistMergeService.call(target: target, source: source)

        json_response(
          absorbed.merge(artist: API::V1::ArtistSerializer.render_as_hash(target.reload, view: :full))
        )
      rescue ArtistMergeService::Error => e
        error_response(e.message)
      end
    end
  end
end
