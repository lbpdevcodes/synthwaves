class API::V1::ArtistMergesController < API::V1::MergesController
  private

  def records = current_user.artists

  def merger = ArtistMergeService

  def serializer = API::V1::ArtistSerializer

  def survivor_id = params[:artist_id]

  def source_id = params[:source_artist_id]
end
