class Video < ApplicationRecord
  include Downloadable

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
  has_many :favorites, as: :favorable, dependent: :destroy
  has_many :video_playback_positions, dependent: :destroy
  has_many :subtitles, -> { order(:label) }, class_name: "VideoSubtitle", dependent: :destroy

  validates :title, presence: true
  validate :folder_in_same_library, if: :folder_link_changing?

  scope :ready, -> { where(status: "ready") }
  scope :search, ->(q) { q.present? ? where("title LIKE ?", "%#{q}%") : all }
  scope :standalone, -> { where(folder_id: nil) }
  scope :in_folder, -> { where.not(folder_id: nil) }
  scope :ordered, -> { order(:season_number, :episode_number) }

  after_create_commit :convert_video

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
