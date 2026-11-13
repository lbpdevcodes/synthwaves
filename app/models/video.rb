class Video < ApplicationRecord
  include Downloadable
  include Genres
  include Defaults

  FOLDER_SORT_OPTIONS = {
    "episode_number" => "Episode Number",
    "title" => "Title",
    "created_at" => "Date Added"
  }.freeze

  belongs_to :user
  belongs_to :folder, optional: true
  # Never analyzed: ActiveStorage's video analyzer downloads the whole file
  # to read it, and the video's own columns hold what anything here reads
  # (filled by VideoConversionJob, or by PreparedVideo from bin/import_video).
  has_one_attached :file, analyze: :lazily
  has_one_attached :thumbnail
  has_one_attached :cover_image
  has_many :favorites, as: :favorable, dependent: :destroy
  has_many :video_playback_positions, dependent: :destroy
  has_many :subtitles, -> { order(:label) }, class_name: "VideoSubtitle", dependent: :destroy

  # No type is "Other": a clip that is neither a film nor an episode.
  enum :video_type, {movie: "movie", tv: "tv"}, validate: {allow_nil: true}

  validates :title, presence: true
  validates :year, allow_nil: true, numericality: {
    only_integer: true, greater_than_or_equal_to: -> { release_years.begin }, less_than_or_equal_to: -> { release_years.end }
  }
  validate :folder_in_same_library, if: :folder_link_changing?

  scope :ready, -> { where(status: "ready") }
  scope :search, ->(q) { q.present? ? where("title LIKE ?", "%#{q}%") : all }
  scope :standalone, -> { where(folder_id: nil) }
  scope :in_folder, -> { where.not(folder_id: nil) }
  scope :ordered, -> { order(:season_number, :episode_number) }

  after_create_commit :convert_video

  # From the first films to a few years out, for a release announced early.
  def self.release_years = 1888..(Date.current.year + 5)

  # The image that stands for the video: its poster, else the frame the
  # conversion grabbed. Nil when it has neither.
  def cover
    cover_image.attached? ? cover_image : thumbnail.presence
  end

  private

  def folder_link_changing?
    folder && (will_save_change_to_folder_id? || will_save_change_to_user_id?)
  end

  def folder_in_same_library
    errors.add(:folder, "must be one of your folders") if folder.user_id != user_id
  end

  # A video filed ready (PreparedVideo) has nothing left to convert.
  def convert_video
    return unless file.attached? && status == "processing"

    VideoConversionJob.perform_later(id)
  end
end
