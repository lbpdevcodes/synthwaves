class API::V1::AlbumMergesController < API::V1::MergesController
  private

  def records = current_user.albums

  def merger = AlbumMergeService

  def serializer = API::V1::AlbumSerializer

  def survivor_id = params[:album_id]

  def source_id = params[:source_album_id]
end
