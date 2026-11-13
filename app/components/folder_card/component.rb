module FolderCard
  class Component < ViewComponent::Base
    # show_parent names the collection it sits in, for a card seen away
    # from it (a search on the Videos grid).
    def initialize(folder:, show_parent: false)
      @folder = folder
      @show_parent = show_parent
    end

    private

    attr_reader :folder, :show_parent

    # "in TV · 1 collection · 2 seasons · 24 videos", leaving out what
    # doesn't apply, or "Empty". It sits on the card body, not over the
    # image, so list mode keeps it.
    def count_line
      [parent_label, collections, seasons, videos].compact.join(" · ").presence || "Empty"
    end

    def parent_label
      "in #{folder.parent.name}" if show_parent && folder.parent
    end

    def collections
      count = folder.children.size
      helpers.pluralize(count, "collection") if count.positive?
    end

    def videos
      helpers.pluralize(video_count, "video") if video_count.positive?
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
