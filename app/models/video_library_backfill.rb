# Fills the type, year and genres a user's videos lack, from how the user
# filed them before videos had those fields: a collection of numbered
# episodes is TV, a genre folder above a video names its genre, and the
# release name its file was stored under carries its year. It only fills
# blanks and adds genres, so a second run changes nothing.
class VideoLibraryBackfill
  # One video and the fields it would get.
  Change = Data.define(:video, :attributes) do
    def apply = video.update!(attributes)
  end

  # genre_folders names the folders that stood for a genre ("Action").
  def initialize(user, genre_folders:)
    @user = user
    @genres = genre_folders.map(&:downcase)
  end

  # What a run would change, without changing it.
  def changes = videos.filter_map { |video| change_for(video) }

  def apply = changes.each(&:apply)

  # The owner's videos, with what the backfill reads from each.
  def videos = @user.videos.includes(taggings: :tag, file_attachment: :blob)

  # This video's change, or nil when it has nothing left to fill.
  def change_for(video)
    attributes = {video_type: type_for(video), year: year_for(video), genre_names: genres_for(video)}.compact
    Change.new(video, attributes) if attributes.any?
  end

  private

  # A YouTube video is neither, so it stays "Other".
  def type_for(video)
    return if video.video_type || video.youtube_video_id

    episodic?(video) ? "tv" : "movie"
  end

  def year_for(video)
    ReleaseYear.from(video.file.filename) unless video.year
  end

  def genres_for(video)
    genre = genre_above(video.folder_id)
    (video.genre_names | [genre]).sort if genre && video.genre_names.exclude?(genre)
  end

  # The genre of the nearest genre folder at or above this one.
  def genre_above(folder_id)
    folder = folders[folder_id]
    return unless folder

    name = folder.name.downcase
    @genres.include?(name) ? name : genre_above(folder.parent_id)
  end

  def folders = @folders ||= @user.folders.index_by(&:id)

  # A special in a show's collection has no episode number, but its
  # neighbours do.
  def episodic?(video) = video.episode_number.present? || episode_folder_ids.include?(video.folder_id)

  def episode_folder_ids
    @episode_folder_ids ||= @user.videos.where.not(episode_number: nil).where.not(folder_id: nil).distinct.pluck(:folder_id)
  end
end
