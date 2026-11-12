require "rails_helper"

RSpec.describe "A video's folder", type: :request do
  let(:user) { create(:user) }
  let(:folder) { create(:folder, user: user, name: "The Wire") }
  let(:video) { create(:video, user: user, title: "Pilot") }
  let(:turbo) { {"Accept" => "text/vnd.turbo-stream.html, text/html"} }

  before { login_user(user) }

  def refreshed?
    Nokogiri::HTML(response.body).at_css("turbo-stream[action='refresh']:not([request-id])").present?
  end

  describe "PATCH /videos/:video_id/folder" do
    it "moves the video into the folder and refreshes the page" do
      patch video_folder_path(video), params: {folder_id: folder.id}, headers: turbo

      expect(video.reload.folder).to eq(folder)
      expect(refreshed?).to be true
      expect(flash[:notice]).to eq('Moved "Pilot" to The Wire.')
    end

    it "moves a video out of the folder it was in" do
      video.update!(folder: create(:folder, user: user))

      patch video_folder_path(video), params: {folder_id: folder.id}, headers: turbo

      expect(video.reload.folder).to eq(folder)
    end

    it "returns 404 for another user's folder and leaves the video alone" do
      patch video_folder_path(video), params: {folder_id: create(:folder).id}, headers: turbo

      expect(response).to have_http_status(:not_found)
      expect(video.reload.folder).to be_nil
    end

    it "returns 404 for another user's video" do
      other_video = create(:video)

      patch video_folder_path(other_video), params: {folder_id: folder.id}, headers: turbo

      expect(response).to have_http_status(:not_found)
      expect(other_video.reload.folder).to be_nil
    end
  end

  describe "DELETE /videos/:video_id/folder" do
    it "takes the video out of its folder and refreshes the page" do
      video.update!(folder: folder)

      delete video_folder_path(video), headers: turbo

      expect(video.reload.folder).to be_nil
      expect(refreshed?).to be true
      expect(flash[:notice]).to eq('Removed "Pilot" from The Wire.')
    end

    it "returns 404 when the video is in no folder" do
      delete video_folder_path(video), headers: turbo

      expect(response).to have_http_status(:not_found)
    end
  end
end
