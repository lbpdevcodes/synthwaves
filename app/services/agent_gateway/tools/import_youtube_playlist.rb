module AgentGateway
  module Tools
    # Imports a YouTube playlist's metadata, mirroring POST /api/v1/youtube_imports.
    class ImportYoutubePlaylist < AgentGateway::Tool
      tool_name "import_youtube_playlist"
      description "Import a YouTube playlist's METADATA as an album whose tracks have " \
        "has_audio=false. The server does NOT download the audio — YouTube bot-checks " \
        "datacenter IPs, so audio is pushed later by a separate local process. Tell the " \
        "user the music is not playable until that runs. Optionally file the tracks into " \
        "a playlist (playlist_id) or a new one (new_playlist_name)."
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
        album = YoutubeAlbumImportService.call(
          url: url,
          user: user(server_context),
          category: category.presence || "music",
          playlist_id: playlist_id,
          new_playlist_name: new_playlist_name
        )

        return error_response("No videos found in that playlist") if album.nil?

        json_response(
          album_id: album.id,
          title: album.title,
          track_count: album.tracks.count,
          tracks_missing_audio: album.tracks.where.missing(:audio_file_attachment).count
        )
      rescue YoutubePlaylistImportService::Error, YoutubeAPIService::Error, MediaDownloadService::Error => e
        error_response(e.message)
      end
    end
  end
end
