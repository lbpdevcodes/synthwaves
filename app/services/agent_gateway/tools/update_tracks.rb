module AgentGateway
  module Tools
    # Bulk metadata repair: the write counterpart to match_tracks. An agent that
    # has audited a playlist applies its whole correction sheet in one call
    # instead of one call per track.
    class UpdateTracks < AgentGateway::Tool
      tool_name "update_tracks"
      description "Re-tag existing tracks in bulk — artist, title, album and year. Pass a list of " \
        "edits, each naming a track_id plus the tags to change; omitted tags are left alone. " \
        "Artists and albums are given by NAME, not id, and are matched case-insensitively, so " \
        "\"caifanes\" joins an existing \"CAIFANES\" instead of creating a second artist. An " \
        "unknown name creates the record. Changing the artist moves the album with it, so the " \
        "track's album belongs to the artist that now owns the song; name an album to move the " \
        "track to a different one. Each edit succeeds or fails on its own — the reply reports " \
        "updated, failed, and a per-track result — so a sheet is safe to re-send. Send at most " \
        "500 edits per call. Setting year stops MusicBrainz from filling that track's year later."
      annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true)
      input_schema(
        properties: {
          edits: {
            type: "array",
            minItems: 1,
            description: "One entry per track; at most 500 per call",
            # No minLength on the strings. json_schemer rejects the whole call
            # on a schema miss, which would discard 499 good rows for one blank
            # title. Blanks fall through to the model instead and come back as
            # a single failed row, which is the promise this tool makes.
            items: {
              type: "object",
              properties: {
                track_id: {type: "integer"},
                title: {type: "string"},
                artist: {type: "string", description: "Artist name, not id"},
                album: {type: "string", description: "Album title, not id"},
                year: {type: "integer", description: "Release year"}
              },
              required: ["track_id"]
            }
          }
        },
        required: ["edits"]
      )

      def self.perform(edits:, server_context:)
        return too_many_edits if edits.size > MAX_BULK_IDS

        results = edits.map { |edit| apply(user(server_context), edit) }

        json_response(
          updated: results.count { |result| result[:updated] },
          failed: results.count { |result| !result[:updated] },
          results: results
        )
      end

      # One bad row must not discard the rest, so every edit is rescued on its
      # own and reported rather than raised. TrackRetagService wraps each track
      # in its own transaction, so a failed row leaves nothing half-applied.
      def self.apply(user, edit)
        track = user.tracks.find(edit[:track_id])
        TrackRetagService.call(
          track: track,
          title: edit[:title], artist: edit[:artist],
          album: edit[:album], year: edit[:year]
        )
        applied(track)
      rescue ActiveRecord::RecordNotFound
        rejected(edit, "Record not found")
      rescue ActiveRecord::RecordInvalid => e
        rejected(edit, e.record.errors.full_messages.join(", ").presence || e.message)
      rescue ArgumentError => e
        rejected(edit, e.message)
      end

      def self.applied(track)
        {
          track_id: track.id, updated: true, title: track.title,
          artist: track.artist.name, album: track.album.title,
          release_year: track.release_year
        }
      end

      def self.rejected(edit, message)
        {track_id: edit[:track_id], updated: false, error: message}
      end

      # Deliberately not Tool.bulk_limit_error: that message talks about
      # cumulative appends and removals, which means nothing for a re-tag.
      def self.too_many_edits
        error_response("Send at most #{MAX_BULK_IDS} edits per call. Split the sheet and call " \
          "again — each edit is applied on its own, so re-sending one that already landed " \
          "changes nothing.")
      end

      private_class_method :apply, :applied, :rejected, :too_many_edits
    end
  end
end
