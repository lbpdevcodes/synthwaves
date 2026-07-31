require "rails_helper"

RSpec.describe "API::V1::TrackAudio", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:track) { create(:track, :youtube, user: user) }

  describe "POST /api/v1/tracks/:id/audio" do
    it "returns unauthorized without a token" do
      post "/api/v1/tracks/#{track.id}/audio"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns not found for another user's track" do
      other_track = create(:track, :youtube)

      post "/api/v1/tracks/#{other_track.id}/audio", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns unprocessable when no audio file is provided" do
      post "/api/v1/tracks/#{track.id}/audio", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(track.reload.audio_file).not_to be_attached
    end

    it "attaches the uploaded audio and marks the download completed" do
      file = fixture_file_upload("test.mp3", "audio/mpeg")

      post "/api/v1/tracks/#{track.id}/audio", params: {audio_file: file}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      track.reload
      expect(track.audio_file).to be_attached
      expect(track.download_status).to eq("completed")
      expect(track.download_error).to be_nil
      expect(track.file_format).to eq("mp3")
      expect(track.file_size).to eq(track.audio_file.byte_size)
      json = JSON.parse(response.body)
      expect(json["has_audio"]).to be(true)
    end

    it "applies duration and bitrate from the extracted metadata" do
      allow(MetadataExtractor).to receive(:call).and_return({duration: 200.0, bitrate: 192})
      file = fixture_file_upload("test.mp3", "audio/mpeg")

      post "/api/v1/tracks/#{track.id}/audio", params: {audio_file: file}, headers: auth_headers

      track.reload
      expect(track.duration).to eq(200.0)
      expect(track.bitrate).to eq(192)
    end

    it "is a no-op when audio is already attached" do
      track_with_audio = create(:track, user: user)
      original_blob_id = track_with_audio.audio_file.blob.id
      file = fixture_file_upload("test.mp3", "audio/mpeg")

      post "/api/v1/tracks/#{track_with_audio.id}/audio", params: {audio_file: file}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(track_with_audio.reload.audio_file.blob.id).to eq(original_blob_id)
    end
  end
end
