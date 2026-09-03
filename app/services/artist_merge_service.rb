# Folds one artist into another: the source's albums, tracks and favorites move
# to the target, then the source is destroyed. Modelled on AlbumMergeService.
#
# The order inside the transaction is not arbitrary. Album#reassign_tracks_to_artist
# is an after_update_commit callback, so it has not run while this transaction is
# still open -- an album that just changed hands still carries tracks crediting
# the source. The track sweep therefore runs after the albums move and before the
# destroy, because Artist has_many :tracks, dependent: :destroy would otherwise
# delete the music this merge exists to keep.
class ArtistMergeService
  class Error < StandardError; end

  def self.call(target:, source:)
    new(target: target, source: source).call
  end

  def initialize(target:, source:)
    @target = target
    @source = source
  end

  def call
    refuse_impossible_merges
    ActiveRecord::Base.transaction { absorb_source }
  end

  private

  attr_reader :target, :source

  def refuse_impossible_merges
    raise Error, "Cannot merge an artist into itself." if target.id == source.id
    raise Error, "Cannot merge artists from different libraries." unless target.user_id == source.user_id
  end

  def absorb_source
    source.albums.find_each { |album| absorb_album(album) }
    source.tracks.find_each { |track| track.update!(artist: target) }
    source.favorites.find_each { |favorite| absorb_favorite(favorite) }
    source.destroy!
  end

  # Album titles are unique per artist, so a same-titled album cannot simply
  # change hands. Fold it into the target's copy instead.
  def absorb_album(album)
    twin = target.albums.find_by(title: album.title)
    twin ? AlbumMergeService.call(target: twin, source: album) : album.update!(artist: target)
  end

  # favorites is uniquely indexed on user and favorable, so somebody who
  # already favorites the target keeps one row rather than gaining a second.
  def absorb_favorite(favorite)
    if target.favorites.exists?(user_id: favorite.user_id)
      favorite.destroy!
    else
      favorite.update!(favorable: target)
    end
  end
end
