class API::Import::MultipartUploadsController < API::Import::BaseController
  include MultipartUploadRequest

  def create
    upload = MultipartDirectUpload.create!(file)

    render json: {signed_id: upload.signed_id, upload_id: upload.upload_id, part_size: upload.part_size}, status: :created
  end

  def destroy
    upload.abort

    head :no_content
  end

  private

  def file
    filename, byte_size, checksum = params.require([:filename, :byte_size, :checksum])
    {filename: filename, byte_size: byte_size, checksum: checksum, content_type: params[:content_type] || "video/mp4"}
  end
end
