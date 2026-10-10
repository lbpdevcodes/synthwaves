module LibraryHelper
  def library_artist_names
    Current.user.artists.order(:name).pluck(:name)
  end

  def library_album_titles
    Current.user.albums.distinct.order(:title).pluck(:title)
  end

  def artist_delete_confirmation(artist)
    "Delete #{artist.name}, #{pluralize(artist.albums.size, "album")}, and #{pluralize(artist.tracks.size, "track")}? This cannot be undone."
  end

  def album_delete_confirmation(album)
    "Delete \"#{album.title}\" and all its tracks? This cannot be undone."
  end

  def track_delete_confirmation(track)
    "Delete \"#{track.title}\"? This cannot be undone."
  end
end
