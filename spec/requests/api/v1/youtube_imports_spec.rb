require "rails_helper"

RSpec.describe "API::V1::YoutubeImports", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "POST /api/v1/youtube_imports" do
    it "returns unauthorized without a token" do
      post "/api/v1/youtube_imports", params: {url: "https://www.youtube.com/playlist?list=PL123"}

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unprocessable for an invalid playlist URL" do
      post "/api/v1/youtube_imports", params: {url: "https://example.com/not-a-playlist"}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to be_present
    end

    it "returns unprocessable when the playlist has no videos" do
      allow(YoutubePlaylistImportService).to receive(:call).and_return(nil)

      post "/api/v1/youtube_imports",
        params: {url: "https://www.youtube.com/playlist?list=PLempty"},
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to be_present
    end

    it "returns unprocessable when playlist metadata cannot be fetched" do
      allow(YoutubePlaylistImportService).to receive(:call)
        .and_raise(MediaDownloadService::Error, "yt-dlp failed: Sign in to confirm you're not a bot")

      post "/api/v1/youtube_imports",
        params: {url: "https://www.youtube.com/playlist?list=PLblocked"},
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("not a bot")
    end

    it "returns unprocessable when the YouTube API rejects the request" do
      allow(YoutubePlaylistImportService).to receive(:call)
        .and_raise(YoutubeAPIService::Error, "The request cannot be completed because you have exceeded your quota")

      post "/api/v1/youtube_imports",
        params: {url: "https://www.youtube.com/playlist?list=PLquota"},
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("quota")
    end

    context "with a successful import" do
      let(:artist) { create(:artist, user: user) }
      let(:album) { create(:album, artist: artist, user: user, title: "Imported Album") }

      before do
        create(:track, :youtube, album: album, artist: artist, user: user, track_number: 1)
        create(:track, :youtube, album: album, artist: artist, user: user, track_number: 2)
        create(:track, album: album, artist: artist, user: user, track_number: 3)
        allow(YoutubePlaylistImportService).to receive(:call).and_return(album)
      end

      it "returns the album summary with download counts" do
        post "/api/v1/youtube_imports",
          params: {url: "https://www.youtube.com/playlist?list=PLtest123"},
          headers: auth_headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["album_id"]).to eq(album.id)
        expect(json["title"]).to eq("Imported Album")
        expect(json["track_count"]).to eq(3)
        expect(json["tracks_missing_audio"]).to eq(2)
      end

      it "imports via YoutubePlaylistImportService with the user's credentials" do
        post "/api/v1/youtube_imports",
          params: {url: "https://www.youtube.com/playlist?list=PLtest123", category: "podcast"},
          headers: auth_headers

        expect(YoutubePlaylistImportService).to have_received(:call)
          .with("https://www.youtube.com/playlist?list=PLtest123",
            category: "podcast", api_key: user.youtube_api_key, user: user, artist: nil)
      end

      it "does not enqueue any MediaDownloadJob" do
        expect {
          post "/api/v1/youtube_imports",
            params: {url: "https://www.youtube.com/playlist?list=PLtest123"},
            headers: auth_headers
        }.not_to have_enqueued_job(MediaDownloadJob)
      end

      it "adds imported tracks to an existing playlist" do
        playlist = create(:playlist, user: user)

        post "/api/v1/youtube_imports",
          params: {url: "https://www.youtube.com/playlist?list=PLtest123", playlist_id: playlist.id},
          headers: auth_headers

        expect(playlist.reload.tracks).to match_array(album.tracks)
      end

      it "ignores a playlist_id belonging to another user" do
        other_playlist = create(:playlist)

        post "/api/v1/youtube_imports",
          params: {url: "https://www.youtube.com/playlist?list=PLtest123", playlist_id: other_playlist.id},
          headers: auth_headers

        expect(other_playlist.reload.tracks).to be_empty
      end

      it "creates a new playlist with the imported tracks" do
        expect {
          post "/api/v1/youtube_imports",
            params: {url: "https://www.youtube.com/playlist?list=PLtest123", new_playlist_name: "My Import"},
            headers: auth_headers
        }.to change(user.playlists, :count).by(1)

        playlist = user.playlists.find_by(name: "My Import")
        expect(playlist.tracks).to match_array(album.tracks)
      end
    end
  end
end
