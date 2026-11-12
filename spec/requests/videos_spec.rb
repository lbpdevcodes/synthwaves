require "rails_helper"

RSpec.describe "Videos", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /videos/new" do
    it "returns success" do
      get new_video_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /videos" do
    it "creates a video with an uploaded file" do
      file = fixture_file_upload("test.mp4", "video/mp4")

      expect {
        post videos_path, params: {video_file: file, title: "My Video"}
      }.to change(Video, :count).by(1)

      video = Video.last
      expect(video.title).to eq("My Video")
      expect(video.status).to eq("processing")
      expect(video.user).to eq(user)
      expect(response).to redirect_to(video_path(video))
    end

    it "uses filename as title when title is blank" do
      file = fixture_file_upload("test.mp4", "video/mp4")

      post videos_path, params: {video_file: file}

      expect(Video.last.title).to eq("test")
    end

    it "enqueues VideoConversionJob" do
      file = fixture_file_upload("test.mp4", "video/mp4")

      expect {
        post videos_path, params: {video_file: file, title: "Test"}
      }.to have_enqueued_job(VideoConversionJob)
    end

    it "rejects when no file is attached" do
      post videos_path, params: {title: "No File"}
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /videos/:id" do
    it "returns success for own video" do
      video = create(:video, user: user)
      get video_path(video)
      expect(response).to have_http_status(:ok)
    end

    it "offers the folder menu beside Edit" do
      folder = create(:folder, user: user, name: "The Wire")
      video = create(:video, user: user, folder: folder)

      get video_path(video)

      doc = Nokogiri::HTML(response.body)
      remove = doc.css("form[action='#{video_folder_path(video)}']").find { |form| form.at_css("input[value='delete']") }
      expect(remove.text).to include("Remove from The Wire")
    end

    it "shows processing state" do
      video = create(:video, :processing, user: user)
      get video_path(video)
      expect(response.body).to include("Processing video")
    end

    it "shows failed state" do
      video = create(:video, :failed, user: user)
      get video_path(video)
      expect(response.body).to include("Processing failed")
    end

    it "returns 404 for another user's video" do
      other_user = create(:user)
      video = create(:video, user: other_user)

      get video_path(video)
      expect(response).to have_http_status(:not_found)
    end

    it "offers each subtitle to the player as a track" do
      video = create(:video, user: user)
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mp4", content_type: "video/mp4")
      english = create(:video_subtitle, video: video, label: "English (SDH)", language: "en", kind: "captions")
      french = create(:video_subtitle, video: video, label: "French", language: "fr", kind: "subtitles")

      get video_path(video)

      tracks = Nokogiri::HTML(response.body).css("video track").map do |track|
        track.to_h.slice("kind", "label", "srclang", "src")
      end
      expect(tracks).to eq([
        {"kind" => "captions", "label" => "English (SDH)", "srclang" => "en", "src" => video_subtitle_path(video, english)},
        {"kind" => "subtitles", "label" => "French", "srclang" => "fr", "src" => video_subtitle_path(video, french)}
      ])
    end
  end

  describe "GET /videos/:id/edit" do
    it "has season and episode fields" do
      video = create(:video, user: user, season_number: 1, episode_number: 3)

      get edit_video_path(video)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("input[name='video[season_number]']")["value"]).to eq("1")
      expect(doc.at_css("input[name='video[episode_number]']")["value"]).to eq("3")
    end

    it "lists the video's subtitles, each with a way to remove it" do
      video = create(:video, user: user)
      subtitle = create(:video_subtitle, video: video, label: "French (Canadian)")

      get edit_video_path(video)

      page = Nokogiri::HTML(response.body)
      expect(page.text).to include("French (Canadian)")
      expect(page.at_css("form[action='#{video_subtitle_path(video, subtitle)}'] input[name='_method'][value='delete']")).to be_present
    end

    it "offers a form to add a subtitle file" do
      video = create(:video, user: user)

      get edit_video_path(video)

      form = Nokogiri::HTML(response.body).at_css("form[action='#{video_subtitles_path(video)}'][enctype='multipart/form-data']")
      expect(form.at_css("input[type='file'][name='subtitle[file]'][accept='.srt,.vtt']")).to be_present
      expect(form.at_css("input[name='subtitle[label]']")).to be_present
    end

    it "returns success" do
      video = create(:video, user: user)
      get edit_video_path(video)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /videos/:id" do
    it "updates the video" do
      video = create(:video, user: user, title: "Old Title")
      patch video_path(video), params: {video: {title: "New Title", description: "Updated"}}

      video.reload
      expect(video.title).to eq("New Title")
      expect(video.description).to eq("Updated")
      expect(response).to redirect_to(video_path(video))
    end

    it "rejects blank title" do
      video = create(:video, user: user)
      patch video_path(video), params: {video: {title: ""}}
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "moves video to a folder" do
      folder = create(:folder, user: user)
      video = create(:video, user: user)

      patch video_path(video), params: {video: {folder_id: folder.id}}

      expect(video.reload.folder).to eq(folder)
    end

    it "saves the season and episode, which order a folder's videos" do
      video = create(:video, user: user)

      patch video_path(video), params: {video: {season_number: "2", episode_number: "5"}}

      expect(video.reload).to have_attributes(season_number: 2, episode_number: 5)
    end

    it "refuses to move a video into another user's folder" do
      foreign_folder = create(:folder, user: create(:user))
      video = create(:video, user: user)

      patch video_path(video), params: {video: {folder_id: foreign_folder.id}}

      expect(response).to have_http_status(:unprocessable_content)
      expect(video.reload.folder).to be_nil
    end

    it "removes video from a folder" do
      folder = create(:folder, user: user)
      video = create(:video, user: user, folder: folder)

      patch video_path(video), params: {video: {folder_id: ""}}

      expect(video.reload.folder).to be_nil
    end
  end

  describe "DELETE /videos/:id" do
    it "deletes the video" do
      video = create(:video, user: user)
      expect { delete video_path(video) }.to change(Video, :count).by(-1)
      expect(response).to redirect_to(tv_path(tab: "videos"))
    end
  end

  describe "GET /videos/:id/stream" do
    it "redirects to blob url for ready videos" do
      video = create(:video, user: user, status: "ready")
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mp4", content_type: "video/mp4")

      get stream_video_path(video)
      expect(response).to have_http_status(:redirect)
    end

    it "returns 404 for processing videos" do
      video = create(:video, :processing, user: user)
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mp4", content_type: "video/mp4")

      get stream_video_path(video)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for videos without attached file" do
      video = create(:video, user: user, status: "ready")

      get stream_video_path(video)
      expect(response).to have_http_status(:not_found)
    end
  end
end
