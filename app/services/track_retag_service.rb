# Re-tags one track's artist, title, album and year in place.
#
# The album follows the artist: an edit that moves a track to a different
# artist also moves its album, so track.artist and track.album.artist stay in
# step. Nothing enforces that pairing -- there is no validation and no database
# constraint, and DeleteEmptyArtistsTask heals divergence in favour of the
# album -- so this service keeps the pair together deliberately.
#
# Albums a move empties are left for Maintenance::DeleteEmptyAlbumsTask.
# Artists are never destroyed here: Artist has_many :tracks, dependent: :destroy,
# so deleting an emptied artist would take tracks with it.
class TrackRetagService
  def self.call(track:, title: nil, artist: nil, album: nil, year: nil)
    new(track, title: title, artist: artist, album: album, year: year).call
  end

  def initialize(track, title:, artist:, album:, year:)
    @track = track
    @title = title
    @artist_name = artist
    @album_title = album
    @year = year
  end

  # Writes through update! rather than update_all: the FTS5 index is maintained
  # by Track's after_update_commit callback, which update_all would skip.
  def call
    raise ArgumentError, "name at least one of title, artist, album or year" if no_tags_given?

    ActiveRecord::Base.transaction { track.update!(new_tags) }
    track
  end

  private

  attr_reader :track, :title, :artist_name, :album_title, :year

  def no_tags_given?
    [title, artist_name, album_title, year].all?(&:nil?)
  end

  def new_tags
    {title: title, release_year: year}.compact
      .merge(artist: target_artist, album: target_album)
  end

  def target_artist
    @target_artist ||= artist_name ? resolved_artist : track.artist
  end

  def target_album
    @target_album ||= moving_album? ? resolved_album : track.album
  end

  # A named album moves the track; so does a new artist, which takes the
  # current album title along to the artist that now owns the song.
  def moving_album?
    album_title.present? || target_artist != track.artist
  end

  def resolved_artist
    user.artists.named(artist_name).first || user.artists.create!(name: artist_name)
  end

  def resolved_album
    user.albums.find_or_create_by!(title: album_title || track.album.title, artist: target_artist)
  end

  def user
    track.user
  end
end
