require "rails_helper"

RSpec.describe "API Import Videos", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "POST /api/import/videos" do
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake video data"),
        filename: "test_video.mp4",
        content_type: "video/mp4"
      )
    end

    it "creates a video from a signed blob ID" do
      expect {
        post api_import_videos_path,
          params: {signed_blob_id: blob.signed_id, title: "My Video"},
          headers: auth_headers
      }.to change(Video, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["id"]).to be_present
      expect(json["title"]).to eq("My Video")
      expect(json["folder"]).to be_nil
      expect(json["status"]).to eq("processing")
    end

    it "defaults title to blob filename" do
      post api_import_videos_path,
        params: {signed_blob_id: blob.signed_id},
        headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("test_video")
    end

    it "creates a video with folder" do
      post api_import_videos_path,
        params: {
          signed_blob_id: blob.signed_id,
          title: "Episode 1",
          folder_name: "My Show",
          season_number: 1,
          episode_number: 1
        },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["folder"]).to eq("My Show")

      video = Video.last
      expect(video.folder.name).to eq("My Show")
      expect(video.season_number).to eq(1)
      expect(video.episode_number).to eq(1)
    end

    it "reuses existing folder" do
      folder = create(:folder, user: user, name: "Existing Show")

      expect {
        post api_import_videos_path,
          params: {signed_blob_id: blob.signed_id, title: "EP1", folder_name: "Existing Show"},
          headers: auth_headers
      }.not_to change(Folder, :count)

      expect(Video.last.folder).to eq(folder)
    end

    it "files the video in the one folder with that name, however deep it sits" do
      the_wire = create(:folder, user: user, parent: create(:folder, user: user, name: "TV"), name: "The Wire")

      post api_import_videos_path,
        params: {signed_blob_id: blob.signed_id, title: "EP1", folder_name: "The Wire"},
        headers: auth_headers

      expect(Video.last.folder).to eq(the_wire)
    end

    it "refuses a folder name several folders share, naming each by its path" do
      %w[South\ Park The\ Wire].each do |show|
        create(:folder, user: user, parent: create(:folder, user: user, name: show), name: "Season 1")
      end

      expect {
        post api_import_videos_path,
          params: {signed_blob_id: blob.signed_id, title: "EP1", folder_name: "Season 1"},
          headers: auth_headers
      }.not_to change(Video, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"])
        .to eq("Several folders are named Season 1: South Park › Season 1 and The Wire › Season 1")
    end

    it "files the video with the type, year and genres sent" do
      post api_import_videos_path,
        params: {signed_blob_id: blob.signed_id, video_type: "tv", year: 1999, genres: ["Comedy", "crime"]},
        headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(Video.last).to have_attributes(video_type: "tv", year: 1999, genre_names: %w[comedy crime])
    end

    it "files a video sent without them as a movie of the year its file name gives" do
      heat = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("video"), filename: "Heat.1995.1080p.BluRay.mp4", content_type: "video/mp4")

      post api_import_videos_path, params: {signed_blob_id: heat.signed_id}, headers: auth_headers

      expect(Video.last).to have_attributes(video_type: "movie", year: 1995, genre_names: [])
    end

    it "refuses a type it doesn't know, saying why" do
      post api_import_videos_path,
        params: {signed_blob_id: blob.signed_id, video_type: "cartoon"},
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to include("Video type is not included in the list")
    end

    it "enqueues VideoConversionJob" do
      expect {
        post api_import_videos_path,
          params: {signed_blob_id: blob.signed_id, title: "Convert Me"},
          headers: auth_headers
      }.to have_enqueued_job(VideoConversionJob)
    end

    it "returns unprocessable_entity for invalid signed blob ID" do
      post api_import_videos_path,
        params: {signed_blob_id: "invalid", title: "Bad"},
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Invalid signed blob ID")
    end

    it "returns unauthorized without valid credentials" do
      post api_import_videos_path,
        params: {signed_blob_id: blob.signed_id},
        headers: {"Authorization" => "Bearer invalid"}

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized without any credentials" do
      post api_import_videos_path, params: {signed_blob_id: blob.signed_id}

      expect(response).to have_http_status(:unauthorized)
    end

    # bin/import_video sends the thumbnail and the details VideoConversionJob
    # would store, for a file the job would keep as it is.
    context "with the thumbnail and details of a file prepared for it" do
      let(:thumbnail) { ActiveStorage::Blob.create_and_upload!(io: StringIO.new("jpeg"), filename: "thumbnail.jpg", content_type: "image/jpeg") }
      let(:details) do
        {duration: 5966.0, width: 1912, height: 800, video_codec: "h264", audio_codec: "aac",
         audio_channels: 2, bitrate: 1825, container: "mov,mp4,m4a,3gp,3g2,mj2"}
      end

      def file_prepared(**changes)
        post api_import_videos_path, as: :json, headers: auth_headers,
          params: {signed_blob_id: blob.signed_id, title: "Kung Fu Hustle", thumbnail_signed_blob_id: thumbnail.signed_id, details: details}.merge(changes)
      end

      it "files it ready, with its thumbnail and details, and starts no conversion" do
        expect { file_prepared }.not_to have_enqueued_job(VideoConversionJob)

        video = Video.last
        expect(JSON.parse(response.body)["status"]).to eq("ready")
        expect(video.thumbnail.blob).to eq(thumbnail)
        expect(video.attributes.symbolize_keys.slice(*details.keys - [:container])).to eq(details.except(:container))
      end

      it "leaves a file whose details say it needs converting to the job" do
        expect { file_prepared(details: details.merge(audio_channels: 6)) }.to have_enqueued_job(VideoConversionJob)

        expect(Video.last.status).to eq("processing")
        expect(Video.last.thumbnail).not_to be_attached
      end

      it "leaves a file sent without its thumbnail to the job" do
        expect { file_prepared(thumbnail_signed_blob_id: nil) }.to have_enqueued_job(VideoConversionJob)

        expect(Video.last.status).to eq("processing")
      end

      it "returns unprocessable_entity for a thumbnail signed blob ID it cannot verify" do
        expect { file_prepared(thumbnail_signed_blob_id: "invalid") }.not_to change(Video, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to eq("Invalid signed blob ID")
      end
    end
  end
end
