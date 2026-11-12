class Folder < ApplicationRecord
  include Nesting

  belongs_to :user
  has_many :videos, dependent: :nullify
  has_one_attached :cover_image
  has_many :favorites, as: :favorable, dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: [:user_id, :parent_id]}

  scope :search, ->(q) { q.present? ? where("name LIKE ?", "%#{q}%") : all }

  class AmbiguousName < StandardError; end

  # The folder a name stands for, at any depth, made at the top level when
  # there is none. A name several folders share stands for none of them.
  def self.find_or_create_named!(user, name)
    matches = user.folders.where(name: name).to_a
    raise AmbiguousName, ambiguity(user, name, matches) if matches.many?

    matches.first || user.folders.create!(name: name)
  end

  def self.ambiguity(user, name, matches)
    tree = FolderTree.new(user.folders.to_a)
    "Several folders are named #{name}: #{matches.map { |folder| tree.label(folder) }.sort.to_sentence}"
  end
  private_class_method :ambiguity

  # The image that stands for the folder: its own cover, else the first
  # ready episode's thumbnail, else the first subfolder's cover by name.
  # Nil when it has none of them.
  def cover
    return cover_image if cover_image.attached?

    first_thumbnail || subfolder_cover
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

  def subfolder_cover
    children.order(:name).lazy.filter_map(&:cover).first
  end
end
