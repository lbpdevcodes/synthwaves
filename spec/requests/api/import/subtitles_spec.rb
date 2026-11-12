require "rails_helper"

RSpec.describe "API Import Subtitles", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:video) { create(:video, user: user) }
  let(:srt) { "1\n00:00:02,000 --> 00:00:07,500\nHola\n" }

  def upload(to: video, filename: "Latin American.spa.srt", content: srt, headers: auth_headers)
    post api_import_video_subtitles_path(to), params: {filename: filename, content_base64: [content].pack("m0")},
      headers: headers, as: :json
  end

  describe "POST /api/import/videos/:video_id/subtitles" do
    it "files a base64-encoded subtitle file on the video" do
      upload

      subtitle = video.subtitles.sole
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq(
        "id" => subtitle.id, "label" => "Spanish (Latin American)", "language" => "es", "kind" => "subtitles"
      )
    end

    it "refuses a file with no subtitles in it, saying which file and why" do
      upload(filename: "notes.txt", content: "just some notes")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("error" => "notes.txt: no subtitle cues found")
      expect(video.subtitles).to be_empty
    end

    it "does not file subtitles on another user's video" do
      other_video = create(:video)

      upload(to: other_video)

      expect(response).to have_http_status(:not_found)
      expect(other_video.subtitles).to be_empty
    end

    it "requires a token" do
      upload(headers: {})

      expect(response).to have_http_status(:unauthorized)
      expect(video.subtitles).to be_empty
    end
  end
end
