class Artist < ApplicationRecord
  include SearchIndexable

  belongs_to :user
  has_many :albums, dependent: :destroy
  has_many :tracks, dependent: :destroy
  has_many :favorites, as: :favorable, dependent: :destroy

  enum :category, {music: "music", podcast: "podcast"}, default: "music"

  CATEGORIES = categories.keys

  SORT_OPTIONS = {
    "name" => "Name",
    "created_at" => "Recently Added"
  }.freeze

  validates :name, presence: true, uniqueness: {scope: :user_id}

  after_update_commit :reindex_tracks_search, if: :saved_change_to_name?

  scope :search, ->(query) {
    where("artists.name LIKE :q", q: "%#{query}%") if query.present?
  }

  # Exact name match, ignoring case, so a repair joins the library's existing
  # row ("CAIFANES") instead of spawning a near-duplicate beside it.
  scope :named, ->(name) { where("LOWER(name) = ?", name.to_s.downcase) }

  # The one way to turn an artist name into a record. Scoped to the user, so a
  # repair never borrows another library's artist, and case-insensitive, so it
  # does not stack "Mana" beside "Maná".
  def self.find_or_create_named!(user, name)
    user.artists.named(name).first || user.artists.create!(name: name)
  end

  private
end
