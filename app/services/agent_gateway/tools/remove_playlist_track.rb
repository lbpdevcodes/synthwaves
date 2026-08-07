module AgentGateway
  module Tools
    # Removes one entry from a playlist, mirroring
    # DELETE /api/v1/playlists/:id/tracks/:playlist_track_id.
    class RemovePlaylistTrack < AgentGateway::Tool
      tool_name "remove_playlist_track"
      description "Remove one entry from a playlist by its playlist_track_id (from get_playlist — " \
        "NOT the track ID). The track itself stays in the library."
      annotations(read_only_hint: false, destructive_hint: true)
      input_schema(
        properties: {
          playlist_id: {type: "integer"},
          playlist_track_id: {type: "integer"}
        },
        required: ["playlist_id", "playlist_track_id"]
      )

      def self.perform(playlist_id:, playlist_track_id:, server_context:)
        playlist = user(server_context).playlists.find(playlist_id)
        playlist.playlist_tracks.find(playlist_track_id).destroy!

        json_response(removed: true, tracks_count: playlist.reload.playlist_tracks_count)
      end
    end
  end
end
