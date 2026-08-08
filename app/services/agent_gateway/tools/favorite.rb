module AgentGateway
  module Tools
    # Favorites a record, mirroring POST /api/v1/favorites.
    class Favorite < AgentGateway::Tool
      tool_name "favorite"
      description "Favorite a track, album, or artist. Idempotent: favoriting an already-favorited " \
        "record succeeds and changes nothing."
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
        favorable = find_favorable(user, favorable_type, favorable_id)
        favorite = user.favorites.find_or_create_by!(favorable: favorable)

        json_response(API::V1::FavoriteSerializer.render_as_hash(favorite))
      end
    end
  end
end
