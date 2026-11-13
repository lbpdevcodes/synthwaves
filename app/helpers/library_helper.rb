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

  def playlist_delete_confirmation(playlist)
    "Delete \"#{playlist.name}\"? Its tracks stay in your library."
  end

  # The page a folder sits on: its parent folder's, or the Videos grid.
  def folder_parent_path(folder)
    folder.parent ? folder_path(folder.parent) : tv_path(tab: "videos")
  end

  # [path label, id] for each of the folders, for a folder select.
  def folder_select_options(folders = current_folder_tree)
    folders.map { |folder| [current_folder_tree.label(folder), folder.id] }
  end

  # The select options for the folders this one could sit inside.
  def folder_parent_options(folder)
    folder_select_options(current_folder_tree.possible_parents_for(folder))
  end

  def folder_delete_confirmation(folder)
    question = "Delete \"#{folder.name}\"?"
    contents = folder_contents(folder)
    return question if contents.empty?

    "#{question} #{contents} in it will #{folder.parent ? "move to #{folder.parent.name}" : "stay in your library, under Videos"}."
  end

  # What a collection holds, collections first: "1 collection and 2 videos".
  # Blank when empty.
  def folder_contents(folder)
    {"collection" => folder.children.size, "video" => folder.videos.size}
      .reject { |_noun, count| count.zero? }
      .map { |noun, count| pluralize(count, noun) }
      .to_sentence
  end
end
