class API::Import::VideosController < API::Import::BaseController
  def create
    blob = ActiveStorage::Blob.find_signed!(params[:signed_blob_id])
    thumbnail = ActiveStorage::Blob.find_signed!(params[:thumbnail_signed_blob_id]) if params[:thumbnail_signed_blob_id].present?

    folder = Folder.find_or_create_named!(current_user, params[:folder_name]) if params[:folder_name].present?

    video = Video.new(
      user: current_user,
      folder: folder,
      title: params[:title] || blob.filename.base,
      season_number: params[:season_number],
      episode_number: params[:episode_number],
      video_type: params[:video_type],
      year: params[:year],
      genre_names: params[:genres],
      file_format: blob.filename.extension,
      file_size: blob.byte_size,
      status: "processing"
    )
    video.file.attach(blob)
    PreparedVideo.new(video, details: details_params, thumbnail: thumbnail).apply
    video.save!

    render json: {
      id: video.id,
      title: video.title,
      folder: folder&.name,
      status: video.status
    }, status: :created
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    render json: {error: "Invalid signed blob ID"}, status: :unprocessable_content
  rescue ActiveRecord::RecordInvalid, Folder::AmbiguousName => e
    render json: {error: e.message}, status: :unprocessable_content
  end

  private

  def details_params = params.fetch(:details, {}).permit(*PreparedVideo::DETAILS)
end
