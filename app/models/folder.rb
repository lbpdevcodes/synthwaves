class Folder < ApplicationRecord
  belongs_to :user
  has_many :videos, dependent: :nullify
  has_one_attached :cover_image
  has_many :favorites, as: :favorable, dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :user_id}

  scope :search, ->(q) { q.present? ? where("name LIKE ?", "%#{q}%") : all }

  # The image that stands for the folder: its own cover, else the first
  # ready episode's thumbnail. Nil when it has neither.
  def cover
    cover_image.attached? ? cover_image : first_thumbnail
  end

  private

  def first_thumbnail
    videos.ready.ordered.joins(:thumbnail_attachment).first&.thumbnail
  end
end
