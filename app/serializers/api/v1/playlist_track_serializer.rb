module API
  module V1
    class PlaylistTrackSerializer < Blueprinter::Base
      view :full do
        field :position
        field :playlist_track_id do |pt|
          pt.id
        end
        association :track, blueprint: TrackSerializer, view: :embedded
      end

      # Flat token-lean row for large playlist reads (MCP get_playlist).
      view :compact do
        field :position
        field :playlist_track_id do |pt|
          pt.id
        end
        field :track_id
        field :title do |pt|
          pt.track.title
        end
        field :artist do |pt|
          pt.track.artist.name
        end
        field :duration do |pt|
          pt.track.duration
        end
      end
    end
  end
end
