class API::Import::MultipartUploads::CompletionsController < API::Import::BaseController
  include MultipartUploadRequest

  def create
    upload.complete(parts)

    render json: {signed_id: params[:signed_id]}, status: :ok
  end

  private

  def parts
    params.require(:parts).map { |part| {part_number: part.require(:part_number).to_i, etag: part.require(:etag)} }
  end
end
