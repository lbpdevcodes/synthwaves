# A video's genres: the genre tags, shared with tracks, its owner files it
# under. A video can have several (Batman Begins: action, crime).
module Video::Genres
  extend ActiveSupport::Concern

  # How a video was made, not what it is about: named as a genre, it marks the
  # video animated instead (Shrek is animated, and a comedy).
  ANIMATED = "animated"

  included do
    has_many :taggings, as: :taggable, dependent: :destroy, autosave: true
    has_many :tags, through: :taggings

    scope :by_genre, ->(name) { joins(:tags).where(tags: {tag_type: "genre", name: name.downcase}).distinct }

    # Genres can be named before the owner is (Video.new(genre_names: ..., user: ...)).
    before_validation :give_new_taggings_the_owner
    # At validation, so no field assigned after the genres (the edit form's
    # unticked Animated box) can undo it.
    before_validation :mark_animated_when_named
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
    @animated_named = wanted.delete(ANIMATED).present?
    genre_taggings.reject { |tagging| wanted.include?(tagging.tag.name) }.each(&:mark_for_destruction)
    (wanted - genre_names).each { |name| taggings.build(tag: genre_tag(name)) }
  end

  private

  def mark_animated_when_named
    self.animated = true if @animated_named
  end

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
