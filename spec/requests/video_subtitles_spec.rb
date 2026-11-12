require "rails_helper"

RSpec.describe "Video subtitles", type: :request do
  let(:user) { create(:user) }
  let(:video) { create(:video, user: user) }

  before { login_user(user) }

  describe "GET /videos/:video_id/subtitles/:id" do
    it "serves the WebVTT from this origin rather than redirecting to storage" do
      subtitle = create(:video_subtitle, video: video, vtt: "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nBonjour\n")

      get video_subtitle_path(video, subtitle)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vtt")
      expect(response.body).to eq("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nBonjour\n")
    end

    it "does not serve another user's subtitles" do
      subtitle = create(:video_subtitle, video: create(:video))

      get video_subtitle_path(subtitle.video, subtitle)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /videos/:video_id/subtitles" do
    it "files an uploaded subtitle file and returns to the edit page" do
      file = fixture_file_upload("Canadian.fre.srt", "application/x-subrip")

      post video_subtitles_path(video), params: {subtitle: {file: file}}

      expect(video.subtitles.sole).to have_attributes(label: "French (Canadian)", language: "fr")
      expect(response).to redirect_to(edit_video_path(video))
      expect(flash[:notice]).to eq("Added French (Canadian).")
    end

    it "returns to the edit page saying why a file was refused" do
      file = fixture_file_upload("test.png", "image/png")

      post video_subtitles_path(video), params: {subtitle: {file: file}}

      expect(video.subtitles).to be_empty
      expect(response).to redirect_to(edit_video_path(video))
      expect(flash[:alert]).to eq("test.png: no subtitle cues found")
    end

    it "does not file subtitles on another user's video" do
      other_video = create(:video)

      post video_subtitles_path(other_video), params: {subtitle: {file: fixture_file_upload("Canadian.fre.srt")}}

      expect(response).to have_http_status(:not_found)
      expect(other_video.subtitles).to be_empty
    end
  end

  describe "DELETE /videos/:video_id/subtitles/:id" do
    it "removes a subtitle and returns to the edit page" do
      subtitle = create(:video_subtitle, video: video, label: "English")

      delete video_subtitle_path(video, subtitle)

      expect(video.subtitles).to be_empty
      expect(response).to redirect_to(edit_video_path(video))
      expect(flash[:notice]).to eq("Removed English.")
    end
  end
end
