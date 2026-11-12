require "rails_helper"

RSpec.describe "API Import Multipart Uploads", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:upload) { instance_double(MultipartDirectUpload, signed_id: "signed-blob", upload_id: "upload-1", part_size: 104_857_600) }

  def json = JSON.parse(response.body)

  describe "POST /api/import/multipart_upload" do
    let(:file) { {filename: "City of God.mp4", byte_size: 8_000_000_000, checksum: "bWQ1", content_type: "video/mp4"} }

    it "starts an upload in parts for the file described" do
      allow(MultipartDirectUpload).to receive(:create!).with(file).and_return(upload)

      post api_import_multipart_upload_path, params: file, headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to eq("signed_id" => "signed-blob", "upload_id" => "upload-1", "part_size" => 104_857_600)
    end

    it "says so when this server's storage takes no uploads in parts" do
      post api_import_multipart_upload_path, params: file, headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq("error" => "this server's storage takes no uploads in parts")
    end

    it "refuses a file described without its size" do
      post api_import_multipart_upload_path, params: file.except(:byte_size), headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to include("byte_size")
    end

    it "refuses a request without a token" do
      post api_import_multipart_upload_path, params: file, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/import/multipart_upload/parts" do
    let(:part) { {signed_id: "signed-blob", upload_id: "upload-1", part_number: 3, byte_size: 104_857_600, checksum: "cGFydA=="} }
    let(:blob) { ActiveStorage::Blob.create_before_direct_upload!(filename: "City of God.mp4", byte_size: 8_000_000_000, checksum: "bWQ1", content_type: "video/mp4") }

    it "refuses a signed id this server did not sign" do
      post api_import_multipart_upload_parts_path, params: part.merge(signed_id: "forged"), headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq("error" => "invalid signed blob ID")
    end

    it "refuses a part number storage would not take" do
      post api_import_multipart_upload_parts_path, params: part.merge(signed_id: blob.signed_id, part_number: 0), headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq("error" => "part number 0 is outside 1 to 10000")
    end

    it "replies with where to PUT the part and the headers to send" do
      allow(MultipartDirectUpload).to receive(:find).with(signed_id: "signed-blob", upload_id: "upload-1").and_return(upload)
      allow(upload).to receive(:part_url).with(3, byte_size: 104_857_600, checksum: "cGFydA==")
        .and_return(url: "https://storage.test/part-3", headers: {"Content-MD5" => "cGFydA=="})

      post api_import_multipart_upload_parts_path, params: part, headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to eq("url" => "https://storage.test/part-3", "headers" => {"Content-MD5" => "cGFydA=="})
    end
  end

  describe "POST /api/import/multipart_upload/completion" do
    let(:completion) { {signed_id: "signed-blob", upload_id: "upload-1", parts: [{part_number: 1, etag: "\"a\""}, {part_number: 2, etag: "\"b\""}]} }
    let(:parts) { [{part_number: 1, etag: "\"a\""}, {part_number: 2, etag: "\"b\""}] }

    before { allow(MultipartDirectUpload).to receive(:find).with(signed_id: "signed-blob", upload_id: "upload-1").and_return(upload) }

    it "joins the parts and replies with the blob to file" do
      allow(upload).to receive(:complete).with(parts)

      post api_import_multipart_upload_completion_path, params: completion, headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to eq("signed_id" => "signed-blob")
    end

    it "says why storage did not end up with the whole file" do
      allow(upload).to receive(:complete).and_raise(MultipartDirectUpload::Error, "storage holds 5 bytes of the 8 sent")

      post api_import_multipart_upload_completion_path, params: completion, headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq("error" => "storage holds 5 bytes of the 8 sent")
    end
  end

  describe "DELETE /api/import/multipart_upload" do
    it "throws away the parts sent so far" do
      allow(MultipartDirectUpload).to receive(:find).with(signed_id: "signed-blob", upload_id: "upload-1").and_return(upload)
      allow(upload).to receive(:abort)

      delete api_import_multipart_upload_path, params: {signed_id: "signed-blob", upload_id: "upload-1"}, headers: auth_headers, as: :json

      expect(response).to have_http_status(:no_content)
      expect(upload).to have_received(:abort)
    end
  end
end
