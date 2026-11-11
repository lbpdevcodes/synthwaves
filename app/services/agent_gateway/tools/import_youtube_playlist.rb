module AgentGateway
  module Tools
    # Imports a YouTube playlist's metadata, mirroring POST /api/v1/youtube_imports.
    class ImportYoutubePlaylist < AgentGateway::Tool
      tool_name "import_youtube_playlist"
      description "Import a YouTube playlist's METADATA; the tracks have has_audio=false. " \
        "The server does NOT download the audio — YouTube bot-checks datacenter IPs, so " \
        "audio is pushed later by a separate local process. Tell the user the music is not " \
        "playable until that runs. Music is filed by who performed each video (its YouTube " \
        "release note or its own channel, never the playlist owner) into that artist's album " \
        "or \"Singles\", and the playlist itself becomes a library playlist of the same name " \
        "unless playlist_id or new_playlist_name names another. A podcast becomes one album " \
        "under its channel. album_id is set only when every track landed in one album. " \
        "Re-running an import skips videos already imported."
      annotations(read_only_hint: false, destructive_hint: false, open_world_hint: true)
      input_schema(
        properties: {
          url: {type: "string", description: "YouTube playlist URL"},
          category: {type: "string", enum: %w[music podcast], description: "Default music"},
          playlist_id: {type: "integer", description: "Existing playlist to receive the tracks"},
          new_playlist_name: {type: "string", description: "Create a playlist with this name for the tracks"}
        },
        required: ["url"]
      )

      def self.perform(url:, server_context:, category: nil, playlist_id: nil, new_playlist_name: nil)
        import = YoutubeAlbumImportService.call(
          url: url,
          user: user(server_context),
          category: category.presence || "music",
          playlist_id: playlist_id,
          new_playlist_name: new_playlist_name
        )

        return error_response("No videos found in that playlist") if import.nil?

        json_response(import.summary)
      rescue YoutubePlaylistImportService::Error, YoutubeAPIService::Error, MediaDownloadService::Error => e
        error_response(e.message)
      end
    end
  end
end
