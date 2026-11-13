# What one user's video library holds, for the Video side of the Stats page.
# Counts only ready videos, the ones the user can watch.
class VideoLibraryStats
  DECADE = Arel.sql("(videos.year / 10) * 10")

  def initialize(user:)
    @user = user
  end

  def video_count = videos.count

  def movie_count = videos.movie.count

  def episode_count = videos.tv.count

  def other_count = videos.where(video_type: nil).count

  def collection_count = user.folders.top_level.count

  def total_duration = videos.sum(:duration).to_f

  def total_file_size = videos.sum(:file_size).to_i

  def average_duration = videos.average(:duration).to_f

  # {"drama" => 12, ...}: the eight genres with the most videos, most first.
  def genres
    genre_taggings.group("tags.name").distinct
      .order(Arel.sql("COUNT(DISTINCT taggings.taggable_id) DESC, tags.name"))
      .limit(8).count(:taggable_id)
  end

  # {"1990s" => 14, ...}, oldest first. Videos with no year are left out.
  def decades
    videos.where.not(year: nil).group(DECADE).order(DECADE).count.transform_keys { |decade| "#{decade}s" }
  end

  # {"4K" => 3, "1080p" => 40, ...}, biggest first. Videos of unknown size
  # are left out, and so is a resolution no video has.
  def resolutions
    labels = videos.pluck(:width, :height).filter_map { |width, height| VideoResolution.label(width:, height:) }
    labels.tally.sort_by { |name, _| VideoResolution::NAMES.index(name) }.to_h
  end

  private

  attr_reader :user

  def videos = user.videos.ready

  def genre_taggings
    Tagging.joins(:tag).merge(Tag.genres).where(taggable_type: "Video", taggable_id: videos.select(:id))
  end
end
