class API::Import::MultipartUploads::PartsController < API::Import::BaseController
  include MultipartUploadRequest

  def create
    part_url = upload.part_url(params.require(:part_number).to_i, byte_size: params.require(:byte_size), checksum: params.require(:checksum))

    render json: part_url, status: :created
  end
end
