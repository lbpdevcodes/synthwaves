module AgentGateway
  module Tools
    # Folds one album into another, mirroring AlbumsController#merge.
    class MergeAlbums < AgentGateway::Tool
      tool_name "merge_albums"
      description "Fold one album into another and DELETE the source. The source's tracks move " \
        "to the target and take the target's artist; the target keeps its own cover image, or " \
        "inherits the source's when it has none. Use this for one release the library holds " \
        "twice under different titles. Takes IDs, never titles: look both albums up first, " \
        "because this CANNOT BE UNDONE. The reply says how many tracks moved."
      annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: false)
      input_schema(
        properties: {
          target_album_id: {type: "integer", description: "The album that survives"},
          source_album_id: {type: "integer", description: "The album absorbed, then deleted"}
        },
        required: ["target_album_id", "source_album_id"]
      )

      def self.perform(target_album_id:, source_album_id:, server_context:)
        albums = user(server_context).albums
        target = albums.find(target_album_id)
        source = albums.find(source_album_id)
        absorbed = source.tracks.count

        AlbumMergeService.call(target: target, source: source)

        json_response(
          absorbed_tracks: absorbed,
          album: API::V1::AlbumSerializer.render_as_hash(target.reload, view: :full)
        )
      rescue AlbumMergeService::Error => e
        error_response(e.message)
      end
    end
  end
end
