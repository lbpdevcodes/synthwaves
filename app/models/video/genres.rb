# A video's genres: the genre tags, shared with tracks, its owner files it
# under. A video can have several (Batman Begins: action, crime).
module Video::Genres
  extend ActiveSupport::Concern

  included do
    has_many :taggings, as: :taggable, dependent: :destroy, autosave: true
    has_many :tags, through: :taggings

    scope :by_genre, ->(name) { joins(:tags).where(tags: {tag_type: "genre", name: name.downcase}).distinct }

    # Genres can be named before the owner is (Video.new(genre_names: ..., user: ...)).
    before_validation :give_new_taggings_the_owner
  end

  class_methods do
    # The genres these videos are filed under, once each, by name.
    def genre_names
      Tag.where(tag_type: "genre").joins(:taggings)
        .where(taggings: {taggable_type: "Video", taggable_id: select(:id)})
        .distinct.order(:name).pluck(:name)
    end
  end

  def genre_names
    genre_taggings.map { |tagging| tagging.tag.name }.sort
  end

  # Takes "action, Crime" or a list of names: the video's genres from now on.
  def genre_names=(names)
    wanted = normalized(names)
    genre_taggings.reject { |tagging| wanted.include?(tagging.tag.name) }.each(&:mark_for_destruction)
    (wanted - genre_names).each { |name| taggings.build(tag: genre_tag(name)) }
  end

  private

  def genre_tag(name) = Tag.find_or_initialize_by(name: name, tag_type: "genre")

  # Reads only what's in memory, so a save that names no genres loads none.
  def give_new_taggings_the_owner
    taggings.target.select(&:new_record?).each { |tagging| tagging.user ||= user }
  end

  def genre_taggings
    taggings.select { |tagging| tagging.tag.tag_type == "genre" && !tagging.marked_for_destruction? }
  end

  def normalized(names)
    (names.is_a?(String) ? names.split(",") : Array(names)).map { |name| name.strip.downcase }.compact_blank.uniq
  end
end
