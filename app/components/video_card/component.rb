module VideoCard
  class Component < ViewComponent::Base
    # Controls over the card's top-left corner, such as the folder menu. They
    # sit beside the card link, never inside it.
    renders_one :actions

    def initialize(video:, show_episode_number: false, show_folder: false)
      @video = video
      @show_episode_number = show_episode_number
      @show_folder = show_folder
    end

    private

    attr_reader :video

    def show_folder?
      @show_folder && video.folder.present?
    end

    def show_episode_number?
      @show_episode_number && video.episode_number.present?
    end

    def episode_label
      "E#{video.episode_number}"
    end

    # The line under the title: in a search that reaches into collections,
    # the collection and episode ("South Park · S3E2"); otherwise the description.
    def second_line
      folder_label || video.description.presence
    end

    def folder_label
      return unless show_folder?

      [video.folder.name, episode_code].compact.join(" · ")
    end

    def episode_code
      return unless video.episode_number

      video.season_number ? "S#{video.season_number}#{episode_label}" : episode_label
    end

    def formatted_duration
      return nil unless video.duration
      helpers.format_duration(video.duration)
    end

    def resolution_label
      return nil unless video.height
      case video.height
      when 0..480 then "SD"
      when 481..720 then "720p"
      when 721..1080 then "1080p"
      else "4K"
      end
    end
  end
end
