# A video's genres: the genre tags, shared with tracks, its owner files it
# under. A video can have several (Batman Begins: action, crime).
module Video::Genres
  extend ActiveSupport::Concern

  included do
    has_many :taggings, as: :taggable, dependent: :destroy, autosave: true
    has_many :tags, through: :taggings
  end

  def genre_names
    genre_taggings.map { |tagging| tagging.tag.name }.sort
  end

  # Takes "action, Crime" or a list of names: the video's genres from now on.
  def genre_names=(names)
    wanted = normalized(names)
    genre_taggings.reject { |tagging| wanted.include?(tagging.tag.name) }.each(&:mark_for_destruction)
    (wanted - genre_names).each { |name| taggings.build(tag: genre_tag(name), user: user) }
  end

  private

  def genre_tag(name) = Tag.find_or_initialize_by(name: name, tag_type: "genre")

  def genre_taggings
    taggings.select { |tagging| tagging.tag.tag_type == "genre" && !tagging.marked_for_destruction? }
  end

  def normalized(names)
    (names.is_a?(String) ? names.split(",") : Array(names)).map { |name| name.strip.downcase }.compact_blank.uniq
  end
end
