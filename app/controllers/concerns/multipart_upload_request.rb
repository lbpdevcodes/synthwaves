# What every step of an upload in parts shares: the upload the request names,
# and a 422 naming why storage or the server refused a step.
module MultipartUploadRequest
  extend ActiveSupport::Concern

  included do
    rescue_from MultipartDirectUpload::Error, ActiveRecord::RecordInvalid, ActionController::ParameterMissing do |error|
      render json: {error: error.message}, status: :unprocessable_content
    end
  end

  private

  def upload = MultipartDirectUpload.find(signed_id: params.require(:signed_id), upload_id: params.require(:upload_id))
end
