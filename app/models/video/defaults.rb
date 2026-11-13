# What a new video is when whoever files it doesn't say: a numbered episode is
# TV, a YouTube video is neither, anything else a movie; and its year is the
# one in its file's release name. Only on create, so a video its owner later
# makes "Other" stays that way.
module Video::Defaults
  extend ActiveSupport::Concern

  included do
    before_validation :assume_type, :assume_year, on: :create
  end

  private

  def assume_type
    self.video_type ||= assumed_type
  end

  def assumed_type
    return if youtube_video_id

    episode_number ? "tv" : "movie"
  end

  # A year the video would refuse (Blade.Runner.2099) is no default at all.
  def assume_year
    found = ReleaseYear.from(file.filename)
    self.year ||= found if found && Video.release_years.cover?(found)
  end
end
