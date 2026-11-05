class API::V1::PlaylistMergesController < API::V1::MergesController
  private

  def records = current_user.playlists

  def merger = PlaylistMergeService

  def serializer = API::V1::PlaylistSerializer

  def survivor_id = params[:playlist_id]

  def source_id = params[:source_playlist_id]
end
