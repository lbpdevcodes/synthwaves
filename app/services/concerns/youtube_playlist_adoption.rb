# Makes an album the home of a whole YouTube playlist: it remembers the
# playlist URL, which "Refresh from YouTube" needs, and takes the playlist's
# thumbnail as its cover when it has none. Includers provide `url` and
# `playlist_info`.
module YoutubePlaylistAdoption
  include ThumbnailAttachable

  private

  def adopt_playlist(album)
    album.update!(youtube_playlist_url: url) if album.youtube_playlist_url.blank?
    return if playlist_info[:thumbnail_url].blank? || album.cover_image.attached?

    attach_thumbnail(album, playlist_info[:thumbnail_url])
  end
end
