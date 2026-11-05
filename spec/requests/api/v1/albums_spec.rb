require "rails_helper"

RSpec.describe "API::V1::Albums", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:artist) { create(:artist, user: user) }

  describe "GET /api/v1/albums" do
    it "returns paginated albums for the current user" do
      create_list(:album, 3, artist: artist, user: user)
      create(:album) # other user's album

      get "/api/v1/albums", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["albums"].length).to eq(3)
      expect(json["pagination"]["total_count"]).to eq(3)
    end

    it "filters by artist_id" do
      other_artist = create(:artist, user: user)
      create(:album, artist: artist, user: user, title: "Target Album")
      create(:album, artist: other_artist, user: user)

      get "/api/v1/albums", params: {artist_id: artist.id}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["albums"].length).to eq(1)
      expect(json["albums"].first["title"]).to eq("Target Album")
    end

    it "searches by title" do
      create(:album, artist: artist, user: user, title: "Neon Nights")
      create(:album, artist: artist, user: user, title: "Jazz Sessions")

      get "/api/v1/albums", params: {q: "neon"}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["albums"].length).to eq(1)
      expect(json["albums"].first["title"]).to eq("Neon Nights")
    end

    it "returns unauthorized without a token" do
      get "/api/v1/albums"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/albums/:id" do
    it "returns the album with tracks" do
      album = create(:album, artist: artist, user: user)
      create(:track, album: album, artist: artist, user: user, title: "Track 1", track_number: 1)

      get "/api/v1/albums/#{album.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq(album.title)
      expect(json["tracks"].length).to eq(1)
      expect(json["tracks"].first["title"]).to eq("Track 1")
      expect(json["total_duration"]).to be_a(Numeric)
    end

    it "returns not found for another user's album" do
      other_album = create(:album)

      get "/api/v1/albums/#{other_album.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "exposes youtube_video_id and download_status on track summaries" do
      album = create(:album, artist: artist, user: user)
      create(:track, :youtube, album: album, artist: artist, user: user,
        youtube_video_id: "abc123XYZ", download_status: "failed")

      get "/api/v1/albums/#{album.id}", headers: auth_headers

      json = JSON.parse(response.body)
      track_json = json["tracks"].first
      expect(track_json["youtube_video_id"]).to eq("abc123XYZ")
      expect(track_json["download_status"]).to eq("failed")
    end
  end

  describe "POST /api/v1/albums" do
    it "creates an album" do
      expect {
        post "/api/v1/albums", params: {album: {title: "New Album", artist_id: artist.id, year: 2024, genre: "synthwave"}}, headers: auth_headers
      }.to change(Album, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("New Album")
      expect(json["year"]).to eq(2024)
      expect(json["genre"]).to eq("synthwave")
      expect(json["artist"]["id"]).to eq(artist.id)
    end

    it "rejects duplicate title for the same artist" do
      create(:album, artist: artist, user: user, title: "Existing")

      post "/api/v1/albums", params: {album: {title: "Existing", artist_id: artist.id}}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects missing title" do
      post "/api/v1/albums", params: {album: {title: "", artist_id: artist.id}}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/v1/albums/:id" do
    it "updates the album" do
      album = create(:album, artist: artist, user: user, title: "Old Title")

      patch "/api/v1/albums/#{album.id}", params: {album: {title: "New Title", year: 2025}}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("New Title")
      expect(json["year"]).to eq(2025)
    end

    it "returns not found for another user's album" do
      other_album = create(:album)

      patch "/api/v1/albums/#{other_album.id}", params: {album: {title: "Hacked"}}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/albums/:id" do
    it "deletes the album and cascades tracks" do
      album = create(:album, artist: artist, user: user)
      create(:track, album: album, artist: artist, user: user)

      expect {
        delete "/api/v1/albums/#{album.id}", headers: auth_headers
      }.to change(Album, :count).by(-1)
        .and change(Track, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns not found for another user's album" do
      other_album = create(:album)

      delete "/api/v1/albums/#{other_album.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "editing an album by artist name" do
    let(:json) { JSON.parse(response.body) }

    it "creates an album under a named artist, making the artist if needed" do
      post "/api/v1/albums", params: {album: {title: "OutRun", artist_name: "Kavinsky"}}, headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(json["artist"]["name"]).to eq("Kavinsky")
      expect(user.artists.find_by(name: "Kavinsky")).to be_present
    end

    it "moves an album and its tracks to a named artist" do
      album = create(:album, artist: artist, user: user)
      track = create(:track, album: album, artist: artist, user: user)

      patch "/api/v1/albums/#{album.id}", params: {album: {artist_name: "Kavinsky"}}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json["artist"]["name"]).to eq("Kavinsky")
      expect(track.reload.artist.name).to eq("Kavinsky")
    end

    it "reports a title already used by the same artist" do
      create(:album, artist: artist, user: user, title: "Taken")
      album = create(:album, artist: artist, user: user)

      patch "/api/v1/albums/#{album.id}", params: {album: {title: "Taken"}}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to include("Title has already been taken")
    end
  end

  describe "album covers" do
    let(:album) { create(:album, artist: artist, user: user) }
    let(:json) { JSON.parse(response.body) }

    def upload(name, type)
      fixture_file_upload(name, type)
    end

    it "sets a cover from an image file" do
      put "/api/v1/albums/#{album.id}/cover", params: {cover_image: upload("test.png", "image/png")}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json["cover_image_url"]).to be_present
      expect(album.reload.cover_image).to be_attached
    end

    it "replaces an existing cover" do
      album.cover_image.attach(io: StringIO.new("old"), filename: "old.png", content_type: "image/png")

      put "/api/v1/albums/#{album.id}/cover", params: {cover_image: upload("test.png", "image/png")}, headers: auth_headers

      expect(album.reload.cover_image.filename.to_s).to eq("test.png")
    end

    it "refuses a file that isn't an image and keeps the existing cover" do
      album.cover_image.attach(io: StringIO.new("old"), filename: "old.png", content_type: "image/png")

      put "/api/v1/albums/#{album.id}/cover", params: {cover_image: upload("test.mp3", "audio/mpeg")}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to eq("cover_image must be a JPEG, PNG, GIF, or WebP image")
      expect(album.reload.cover_image.filename.to_s).to eq("old.png")
    end

    it "judges the file by its contents, not the type it claims" do
      put "/api/v1/albums/#{album.id}/cover", params: {cover_image: upload("test.mp3", "image/png")}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(album.reload.cover_image).not_to be_attached
    end

    it "requires a file" do
      put "/api/v1/albums/#{album.id}/cover", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "removes a cover" do
      album.cover_image.attach(io: StringIO.new("old"), filename: "old.png", content_type: "image/png")

      delete "/api/v1/albums/#{album.id}/cover", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json["cover_image_url"]).to be_nil
      expect(album.reload.cover_image).not_to be_attached
    end

    it "treats removing a missing cover as done" do
      delete "/api/v1/albums/#{album.id}/cover", headers: auth_headers

      expect(response).to have_http_status(:ok)
    end

    it "answers 404 for another user's album" do
      other = create(:album)

      put "/api/v1/albums/#{other.id}/cover", params: {cover_image: upload("test.png", "image/png")}, headers: auth_headers
      expect(response).to have_http_status(:not_found)

      delete "/api/v1/albums/#{other.id}/cover", headers: auth_headers
      expect(response).to have_http_status(:not_found)
      expect(other.reload.cover_image).not_to be_attached
    end
  end
end
