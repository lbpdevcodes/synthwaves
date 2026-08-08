module AgentGateway
  module Tools
    # Deletes a playlist, mirroring DELETE /api/v1/playlists/:id.
    class DeletePlaylist < AgentGateway::Tool
      tool_name "delete_playlist"
      description "Delete a playlist. The tracks in it are NOT deleted — only the playlist and its track order."
      annotations(read_only_hint: false, destructive_hint: true)
      input_schema(
        properties: {
          playlist_id: {type: "integer"}
        },
        required: ["playlist_id"]
      )

      def self.perform(playlist_id:, server_context:)
        playlist = user(server_context).playlists.find(playlist_id)
        name = playlist.name
        playlist.destroy!

        json_response(deleted: true, id: playlist_id, name: name)
      end
    end
  end
end
