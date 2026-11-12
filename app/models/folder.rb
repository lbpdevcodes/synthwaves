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

  # The owner's videos outside this folder, for picking ones to add: loose
  # videos first, then those in other folders, by folder name and title.
  def videos_to_add
    user.videos.where.not(folder_id: id).or(user.videos.where(folder_id: nil))
      .left_joins(:folder).includes(:folder)
      .order(Arel.sql("videos.folder_id IS NOT NULL"), "folders.name", :title)
  end

  # Files every video in this folder, or none of them.
  def add_videos(videos)
    transaction { videos.each { |video| video.update!(folder: self) } }
  end

  # Takes this folder's own videos out. Videos in another folder stay put.
  def remove_videos(videos)
    transaction { videos.select { |video| video.folder_id == id }.each { |video| video.update!(folder: nil) } }
  end

  private

  def first_thumbnail
    videos.ready.ordered.joins(:thumbnail_attachment).first&.thumbnail
  end
end
