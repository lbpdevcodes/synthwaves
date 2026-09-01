module AgentGateway
  module Tools
    # Bulk free-text -> track-ID resolver for agent playlist workflows:
    # one call instead of one search call per song.
    class MatchTracks < AgentGateway::Tool
      tool_name "match_tracks"
      description "Resolve many free-form track queries to library track IDs in one call — use this " \
        "instead of one search call per song. Each query is \"Artist - Title\" or a bare title. " \
        "Per query returns the best match in the user's library: confidence exact (full title match, " \
        "case-insensitive, artist must match too if given) or partial (title substring). " \
        "Feed the resolved IDs to add_tracks_to_playlist, at most 500 per call."
      annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)
      input_schema(
        properties: {
          queries: {type: "array", items: {type: "string", minLength: 1}, minItems: 1, maxItems: 200}
        },
        required: ["queries"]
      )

      def self.perform(queries:, server_context:)
        current_user = user(server_context)
        results = queries.map do |query|
          result = TrackMatcherService.call(user: current_user, query: query)
          {
            query: query,
            matched: result.track.present?,
            track: result.track && {
              id: result.track.id, title: result.track.title, artist: result.track.artist.name
            },
            confidence: result.confidence
          }
        end

        json_response(results: results)
      end
    end
  end
end
