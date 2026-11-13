module Maintenance
  # Fills one user's video types, years and genres from how they were filed
  # (VideoLibraryBackfill). genre_folders lists the folders that stood for a
  # genre, by name: "Action, Animated, Comedy".
  #
  # Safe to re-run, or to resume: each video is read afresh, and one with
  # nothing left to fill is skipped.
  class VideoLibraryBackfillTask < MaintenanceTasks::Task
    attribute :user_id, :integer
    attribute :genre_folders, :string
    validates :user_id, :genre_folders, presence: true

    def collection = backfill.videos

    def count = collection.count

    def process(video)
      backfill.change_for(video)&.apply
    end

    private

    def backfill
      @backfill ||= VideoLibraryBackfill.new(User.find(user_id), genre_folders: genre_folders.split(",").map(&:strip))
    end
  end
end
