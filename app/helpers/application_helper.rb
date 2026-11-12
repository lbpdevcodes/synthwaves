module ApplicationHelper
  def current_user_playlists
    @current_user_playlists ||= Current.user&.playlists&.order(:name) || []
  end

  def current_user_folders
    @current_user_folders ||= Current.user&.folders&.order(:name)&.to_a || []
  end
end
