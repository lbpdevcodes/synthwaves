class API::V1::PlaylistTrackOrdersController < API::V1::BaseController
  before_action :set_playlist

  def update
    ids = params[:playlist_track_ids]

    unless ids.is_a?(Array) && ids.any?
      return render_error("playlist_track_ids array required")
    end

    @playlist.reorder!(ids)

    render json: {reordered: ids.size}
  end

  private

  def set_playlist
    @playlist = current_user.playlists.find(params[:playlist_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end
end
