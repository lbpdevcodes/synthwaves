require "rails_helper"

RSpec.describe "Folder uploads", type: :request do
  let(:user) { create(:user) }
  let(:folder) { create(:folder, user: user, name: "My Show") }
  let(:modal) { {"Turbo-Frame" => "modal"} }

  before { login_user(user) }

  def create_video_blob(filename: "test.mp4")
    ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("spec/fixtures/files/test.mp4").open,
      filename: filename,
      content_type: "video/mp4"
    )
  end

  def upload(blobs, season_number: "1", filenames: blobs.map { |blob| blob.filename.to_s })
    post folder_uploads_path(folder), headers: modal, params: {
      season_number: season_number,
      signed_blob_ids: blobs.map(&:signed_id),
      filenames: filenames
    }
  end

  describe "GET /folders/:folder_id/uploads/new" do
    it "opens a multi-file upload into the folder in the modal" do
      get new_folder_upload_path(folder), headers: modal

      form = Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog form[action='#{folder_uploads_path(folder)}']")
      expect(form["data-controller"]).to include("bulk-upload")
      expect(form.at_css("input[name='season_number']")).to be_present
      expect(form.at_css("input[type='file'][multiple][accept*='video']")).to be_present
    end

    it "returns 404 for another user's folder" do
      get new_folder_upload_path(create(:folder)), headers: modal

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /folders/:folder_id/uploads" do
    it "files every uploaded video in the folder and refreshes the page under the modal" do
      upload([create_video_blob(filename: "Episode 1.mp4"), create_video_blob(filename: "Episode 2.mp4")])

      expect(folder.videos.count).to eq(2)
      expect(folder.videos.map(&:user).uniq).to eq([user])
      expect(Nokogiri::HTML(response.body).at_css("turbo-stream[action='refresh']:not([request-id])")).to be_present
      expect(flash[:notice]).to eq("Uploading 2 videos to My Show. Each appears here once it's processed.")
    end

    it "parses episode numbers from filenames" do
      upload([create_video_blob(filename: "S01E03 - The Pilot.mp4")])

      video = folder.videos.last
      expect(video.season_number).to eq(1)
      expect(video.episode_number).to eq(3)
      expect(video.title).to eq("The Pilot")
    end

    it "assigns sequential episode numbers when not parseable" do
      upload([create_video_blob(filename: "random_file.mp4"), create_video_blob(filename: "another_file.mp4")], season_number: "2")

      videos = folder.videos.sort_by(&:episode_number)
      expect(videos.map(&:episode_number)).to eq([1, 2])
      expect(videos.map(&:season_number)).to eq([2, 2])
    end

    it "enqueues VideoConversionJob for each video" do
      blobs = [create_video_blob, create_video_blob]

      expect { upload(blobs) }.to have_enqueued_job(VideoConversionJob).exactly(2).times
    end

    it "keeps the modal open with an error when no files were uploaded" do
      expect { upload([]) }.not_to change(Video, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog").text).to include("Choose at least one video file")
    end

    it "returns 404 for another user's folder" do
      other_folder = create(:folder)

      expect {
        post folder_uploads_path(other_folder), headers: modal, params: {signed_blob_ids: [create_video_blob.signed_id]}
      }.not_to change(Video, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
