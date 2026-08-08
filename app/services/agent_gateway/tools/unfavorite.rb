module AgentGateway
  module Tools
    # Removes a favorite, mirroring DELETE /api/v1/favorites.
    class Unfavorite < AgentGateway::Tool
      tool_name "unfavorite"
      description "Unfavorite a track, album, or artist. Idempotent: a record that is not " \
        "favorited returns removed: false rather than an error."
      annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)
      input_schema(
        properties: {
          favorable_type: {type: "string", enum: FAVORABLE_ASSOCIATIONS.keys},
          favorable_id: {type: "integer"}
        },
        required: ["favorable_type", "favorable_id"]
      )

      def self.perform(favorable_type:, favorable_id:, server_context:)
        user = user(server_context)
        find_favorable(user, favorable_type, favorable_id)
        favorite = user.favorites.find_by(favorable_type: favorable_type, favorable_id: favorable_id)

        json_response(removed: favorite.present? && !!favorite.destroy)
      end
    end
  end
end
