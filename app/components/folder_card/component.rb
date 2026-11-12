module FolderCard
  class Component < ViewComponent::Base
    def initialize(folder:)
      @folder = folder
    end

    private

    attr_reader :folder

    # "2 seasons · 24 videos", "3 videos" or "Empty". It sits on the card
    # body, not over the image, so list mode keeps it.
    def count_line
      return "Empty" if video_count.zero?

      [seasons, helpers.pluralize(video_count, "video")].compact.join(" · ")
    end

    def seasons
      helpers.pluralize(season_count, "season") if season_count.positive?
    end

    def video_count
      folder.videos.size
    end

    def season_count
      folder.videos.where.not(season_number: nil).distinct.count(:season_number)
    end
  end
end
