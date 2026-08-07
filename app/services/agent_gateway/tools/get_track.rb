module AgentGateway
  module Tools
    # One track, mirroring GET /api/v1/tracks/:id.
    class GetTrack < AgentGateway::Tool
      tool_name "get_track"
      description "Get one track by ID with full detail: has_audio, lyrics, download status, loudness, YouTube source."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          track_id: {type: "integer"}
        },
        required: ["track_id"]
      )

      def self.perform(track_id:, server_context:)
        track = user(server_context).tracks.find(track_id)

        json_response(API::V1::TrackSerializer.render_as_hash(track, view: :full))
      end
    end
  end
end
