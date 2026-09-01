module AgentGateway
  # Base for the curated MCP tool surface. Results are text content
  # containing JSON built with the same API::V1 serializers the REST API
  # uses. Expected failures become isError tool results (HTTP 200);
  # anything else propagates to the gem's JSON-RPC internal-error handling.
  class Tool < MCP::Tool
    # Ceiling on any array of ids a tool accepts. An agent cannot reliably
    # emit thousands of ids in one tool call, so large playlist edits are
    # chunked instead. See docs/api/mcp.md "Large playlists".
    MAX_BULK_IDS = 500

    class << self
      def call(server_context:, **args)
        perform(server_context:, **args)
      rescue ActiveRecord::RecordNotFound
        error_response("Record not found")
      rescue ActiveRecord::RecordInvalid => e
        error_response(e.record.errors.full_messages.join(", ").presence || e.message)
      end

      private

      def json_response(payload)
        MCP::Tool::Response.new([{type: "text", text: JSON.generate(payload)}])
      end

      def error_response(message)
        MCP::Tool::Response.new([{type: "text", text: message}], error: true)
      end

      # Returns nil when every given array fits, an error response otherwise.
      # The mcp gem validates input_schema before perform runs, so a schema
      # maxItems would preempt this message with json_schemer's wording.
      def bulk_limit_error(*id_arrays)
        return nil if id_arrays.compact.none? { |ids| ids.size > MAX_BULK_IDS }

        error_response("Send at most #{MAX_BULK_IDS} ids per call. Split the list and " \
          "call again — appends and removals are cumulative, so several small calls " \
          "edit a large playlist safely.")
      end

      def user(server_context)
        server_context[:user]
      end

      # User-scoped favorable lookup shared by favorite/unfavorite.
      # Raises RecordNotFound for foreign or missing records.
      def find_favorable(user, type, id)
        association = FAVORABLE_ASSOCIATIONS.fetch(type)
        user.public_send(association).find(id)
      end
    end

    FAVORABLE_ASSOCIATIONS = {"Track" => :tracks, "Album" => :albums, "Artist" => :artists}.freeze
  end
end
