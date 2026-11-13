module ApplicationHelper
  def current_user_playlists
    @current_user_playlists ||= Current.user&.playlists&.order(:name) || []
  end

  # The signed-in user's folders as a tree, built once per request.
  def current_folder_tree
    @current_folder_tree ||= FolderTree.new(Current.user&.folders&.to_a || [])
  end
end
