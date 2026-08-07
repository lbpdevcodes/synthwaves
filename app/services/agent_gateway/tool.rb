module AgentGateway
  # Base for the curated MCP tool surface. Results are text content
  # containing JSON built with the same API::V1 serializers the REST API
  # uses. Expected failures become isError tool results (HTTP 200);
  # anything else propagates to the gem's JSON-RPC internal-error handling.
  class Tool < MCP::Tool
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
        MCP::Tool::Response.new([{type: "text", text: JSON.pretty_generate(payload)}])
      end

      def error_response(message)
        MCP::Tool::Response.new([{type: "text", text: message}], error: true)
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
