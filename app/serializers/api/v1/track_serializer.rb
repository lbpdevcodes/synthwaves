module API
  module V1
    class TrackSerializer < Blueprinter::Base
      identifier :id

      view :minimal do
        field :title
        association :artist, blueprint: ArtistSerializer, view: :ref do |track|
          {name: track.artist.name}
        end
      end

      view :embedded do
        field :title
        field :duration
        association :artist, blueprint: ArtistSerializer, view: :ref
        association :album, blueprint: AlbumSerializer, view: :ref
      end

      view :playlist_entry do
        include_view :embedded
        field :has_audio do |track|
          track.audio_file.attached?
        end
      end

      view :summary do
        fields :title, :track_number, :disc_number, :duration, :file_format,
          :youtube_video_id, :download_status
        field :has_audio do |track|
          track.audio_file.attached?
        end
      end

      view :full do
        fields :title, :track_number, :disc_number, :duration,
          :bitrate, :file_format, :file_size, :lyrics, :language,
          :release_year, :content_rating, :created_at
        field :has_audio do |track|
          track.audio_file.attached?
        end
        association :artist, blueprint: ArtistSerializer, view: :ref
        association :album, blueprint: AlbumSerializer, view: :ref
      end

      # One track, as an edit form needs it. Lists stay on :full to avoid
      # a query per row for tags.
      view :detail do
        include_view :full
        field :tags do |track|
          track.taggings.includes(:tag).map do |tagging|
            {tagging_id: tagging.id, name: tagging.tag.name, tag_type: tagging.tag.tag_type}
          end
        end
      end
    end
  end
end
