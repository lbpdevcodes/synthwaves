class Video < ApplicationRecord
  include Downloadable

  FOLDER_SORT_OPTIONS = {
    "episode_number" => "Episode Number",
    "title" => "Title",
    "created_at" => "Date Added"
  }.freeze

  belongs_to :user
  belongs_to :folder, optional: true
  has_one_attached :file
  has_one_attached :thumbnail
  has_many :favorites, as: :favorable, dependent: :destroy
  has_many :video_playback_positions, dependent: :destroy
  has_many :subtitles, -> { order(:label) }, class_name: "VideoSubtitle", dependent: :destroy

  validates :title, presence: true

  scope :ready, -> { where(status: "ready") }
  scope :search, ->(q) { q.present? ? where("title LIKE ?", "%#{q}%") : all }
  scope :standalone, -> { where(folder_id: nil) }
  scope :in_folder, -> { where.not(folder_id: nil) }
  scope :ordered, -> { order(:season_number, :episode_number) }

  after_create_commit :convert_video

  private

  # A video filed ready (PreparedVideo) has nothing left to convert.
  def convert_video
    return unless file.attached? && status == "processing"

    VideoConversionJob.perform_later(id)
  end
end
