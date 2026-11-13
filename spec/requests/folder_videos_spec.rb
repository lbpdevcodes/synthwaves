require "rails_helper"

RSpec.describe "Adding videos to a folder", type: :request do
  let(:user) { create(:user) }
  let(:folder) { create(:folder, user: user, name: "The Wire") }
  let(:modal) { {"Turbo-Frame" => "modal"} }

  before { login_user(user) }

  describe "GET /folders/:folder_id/videos/new" do
    it "opens a filterable checklist of the user's other videos in the modal" do
      loose = create(:video, user: user, title: "Loose")
      elsewhere = create(:video, user: user, folder: create(:folder, user: user, name: "Deadwood"), title: "Elsewhere")
      create(:video, user: user, folder: folder, title: "Already in")

      get new_folder_video_path(folder), headers: modal

      form = Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog form[action='#{folder_videos_path(folder)}']")
      expect(form.css("input[type='checkbox'][name='video_ids[]']").map { |box| box["value"] }).to eq([loose.id.to_s, elsewhere.id.to_s])
      expect(form.text).to include("in Deadwood")
      expect(form["data-controller"]).to include("list-filter")
      expect(form.at_css("input[data-list-filter-target='input']")).to be_present
    end

    it "names a video's folder by its path" do
      season_one = create(:folder, user: user, parent: create(:folder, user: user, name: "South Park"), name: "Season 1")
      create(:video, user: user, folder: season_one, title: "Cartman")

      get new_folder_video_path(folder), headers: modal

      expect(Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog").text).to include("in South Park › Season 1")
    end

    it "says so when there is nothing to add" do
      get new_folder_video_path(folder), headers: modal

      expect(Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog").text).to include("Every one of your videos is already in The Wire.")
    end

    it "returns 404 for another user's folder" do
      get new_folder_video_path(create(:folder)), headers: modal

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /folders/:folder_id/videos" do
    it "files the checked videos in the folder and refreshes the page under the modal" do
      videos = create_list(:video, 2, user: user)

      post folder_videos_path(folder), params: {video_ids: videos.map(&:id)}, headers: modal

      expect(folder.videos.reload).to match_array(videos)
      expect(Nokogiri::HTML(response.body).at_css("turbo-stream[action='refresh']:not([request-id])")).to be_present
      expect(flash[:notice]).to eq("Added 2 videos to The Wire.")
    end

    it "keeps the modal open with an error when nothing was checked" do
      create(:video, user: user)

      post folder_videos_path(folder), params: {}, headers: modal

      expect(response).to have_http_status(:unprocessable_content)
      expect(Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog").text).to include("Pick at least one video")
    end

    it "files nothing and returns 404 when a video isn't the user's" do
      mine = create(:video, user: user)

      post folder_videos_path(folder), params: {video_ids: [mine.id, create(:video).id]}, headers: modal

      expect(response).to have_http_status(:not_found)
      expect(mine.reload.folder).to be_nil
    end
  end
end
