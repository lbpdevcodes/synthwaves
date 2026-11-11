# Files each video in a YouTube music playlist under the artist who performed
# it (YoutubeTrackAttribution) and in that artist's own album: the album the
# release note names, the playlist itself for a full-album rip, or the artist's
# "Singles". A track and its album always share an artist.
#
# The playlist's grouping is not an album here; YoutubeAlbumImportService keeps
# it as a playlist.
class YoutubeMusicFiling
  include YoutubePlaylistAdoption

  SINGLES = "Singles"

  def initialize(user:, url:, playlist_info:)
    @user = user
    @url = url
    @playlist_info = playlist_info
  end

  # An already-imported video is returned as it is, never re-filed.
  def file(item)
    user.tracks.find_or_create_by!(youtube_video_id: item[:video_id]) do |track|
      track.assign_attributes(attributes_for(attribute(item), item))
    end
  end

  private

  attr_reader :user, :url, :playlist_info

  def attribute(item)
    YoutubeTrackAttribution.call(title: item[:title], description: item[:description],
      channel_name: item[:channel_name], playlist_title: playlist_info[:title])
  end

  def attributes_for(attribution, item)
    artist = Artist.find_or_create_named!(user, attribution.artist)
    {title: attribution.title, artist: artist, album: album_for(attribution, artist),
     release_year: attribution.year, duration: item[:duration], track_number: track_number(attribution, item)}
  end

  # Only a full-album rip's playlist order is its album's track order.
  def track_number(attribution, item)
    item[:position] + 1 if full_album?(attribution)
  end

  def album_for(attribution, artist)
    album = user.albums.find_or_create_by!(title: attribution.album || SINGLES, artist: artist)
    adopt_playlist(album) if full_album?(attribution)
    album
  end

  def full_album?(attribution)
    attribution.tier == :playlist
  end
end
