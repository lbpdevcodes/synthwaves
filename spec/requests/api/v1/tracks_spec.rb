require "rails_helper"

RSpec.describe "API::V1::Tracks", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:artist) { create(:artist, user: user) }
  let(:album) { create(:album, artist: artist, user: user) }

  describe "GET /api/v1/tracks" do
    it "returns paginated tracks for the current user" do
      create_list(:track, 3, album: album, artist: artist, user: user)
      create(:track) # other user's track

      get "/api/v1/tracks", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["tracks"].length).to eq(3)
      expect(json["pagination"]["total_count"]).to eq(3)
    end

    it "filters by album_id" do
      other_album = create(:album, artist: artist, user: user)
      create(:track, album: album, artist: artist, user: user, title: "Target")
      create(:track, album: other_album, artist: artist, user: user)

      get "/api/v1/tracks", params: {album_id: album.id}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["tracks"].length).to eq(1)
      expect(json["tracks"].first["title"]).to eq("Target")
    end

    it "filters by artist_id" do
      other_artist = create(:artist, user: user)
      other_album = create(:album, artist: other_artist, user: user)
      create(:track, album: album, artist: artist, user: user)
      create(:track, album: other_album, artist: other_artist, user: user)

      get "/api/v1/tracks", params: {artist_id: artist.id}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["tracks"].length).to eq(1)
    end

    it "returns unauthorized without a token" do
      get "/api/v1/tracks"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/tracks/:id" do
    it "returns track detail" do
      track = create(:track, album: album, artist: artist, user: user, title: "My Track")

      get "/api/v1/tracks/#{track.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("My Track")
      expect(json["artist"]["name"]).to eq(artist.name)
      expect(json["album"]["title"]).to eq(album.title)
      expect(json["has_audio"]).to be true
    end

    it "returns not found for another user's track" do
      other_track = create(:track)

      get "/api/v1/tracks/#{other_track.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/tracks" do
    context "with explicit params" do
      it "creates a track" do
        expect {
          post "/api/v1/tracks", params: {
            track: {title: "New Track", artist_id: artist.id, album_id: album.id, track_number: 1, duration: 200.0}
          }, headers: auth_headers
        }.to change(Track, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["title"]).to eq("New Track")
        expect(json["artist"]["id"]).to eq(artist.id)
      end

      it "rejects missing title" do
        post "/api/v1/tracks", params: {
          track: {title: "", artist_id: artist.id, album_id: album.id}
        }, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with audio file upload" do
      it "creates a track from uploaded audio" do
        file = fixture_file_upload("test.mp3", "audio/mpeg")

        expect {
          post "/api/v1/tracks", params: {audio_file: file}, headers: auth_headers
        }.to change(Track, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["title"]).to be_present
        expect(json["has_audio"]).to be true
      end
    end

    it "returns error without any valid params" do
      post "/api/v1/tracks", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/v1/tracks/:id" do
    it "updates track metadata" do
      track = create(:track, album: album, artist: artist, user: user, title: "Old Title")

      patch "/api/v1/tracks/#{track.id}", params: {track: {title: "New Title"}}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("New Title")
    end

    it "returns not found for another user's track" do
      other_track = create(:track)

      patch "/api/v1/tracks/#{other_track.id}", params: {track: {title: "Hacked"}}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/tracks/:id with library edits" do
    let(:track) { create(:track, artist: artist, album: album, user: user, release_year: 1984) }
    let(:json) { JSON.parse(response.body) }

    def edit(fields)
      patch "/api/v1/tracks/#{track.id}", params: {track: fields}, headers: auth_headers, as: :json
    end

    it "moves the track to a named artist, taking its album title along" do
      edit(artist_name: "Kavinsky")

      expect(response).to have_http_status(:ok)
      expect(json["artist"]["name"]).to eq("Kavinsky")
      expect(track.reload.album).to have_attributes(title: album.title, artist: track.artist)
      expect(track.album).not_to eq(album)
    end

    it "moves the track to a named album under its artist" do
      edit(album_title: "OutRun")

      expect(json["album"]["title"]).to eq("OutRun")
      expect(track.reload.album.artist).to eq(artist)
    end

    it "keeps the artist and album when their names are blank" do
      edit(artist_name: "", album_title: "", title: "Renamed")

      expect(response).to have_http_status(:ok)
      expect(track.reload).to have_attributes(title: "Renamed", artist: artist, album: album)
    end

    it "saves and returns language, year and content rating" do
      edit(language: "fr", release_year: 2010, content_rating: "clean")

      expect(json).to include("language" => "fr", "release_year" => 2010, "content_rating" => "clean")
    end

    it "clears the year given an empty string" do
      edit(title: track.title, release_year: "")

      expect(response).to have_http_status(:ok)
      expect(track.reload.release_year).to be_nil
    end

    it "clears the year given null" do
      edit(release_year: nil)

      expect(response).to have_http_status(:ok)
      expect(track.reload.release_year).to be_nil
    end

    it "does not let an artist id separate the track from its album" do
      other = create(:artist, user: user)

      edit(title: "Renamed", artist_id: other.id)

      expect(track.reload).to have_attributes(title: "Renamed", artist: artist)
    end

    it "reports a blank title" do
      edit(title: "")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to include("Title can't be blank")
    end
  end

  describe "track tags" do
    let(:track) { create(:track, artist: artist, album: album, user: user) }
    let!(:tagging) { create(:tagging, user: user, taggable: track, tag: create(:tag, name: "synthwave", tag_type: "genre")) }

    it "lists a track's tags when it is shown" do
      get "/api/v1/tracks/#{track.id}", headers: auth_headers

      expect(JSON.parse(response.body)["tags"]).to eq(
        [{"tagging_id" => tagging.id, "name" => "synthwave", "tag_type" => "genre"}]
      )
    end

    it "lists a track's tags after an edit" do
      patch "/api/v1/tracks/#{track.id}", params: {track: {title: "Renamed"}}, headers: auth_headers

      expect(JSON.parse(response.body)["tags"].map { |tag| tag["name"] }).to eq(["synthwave"])
    end

    it "leaves tags out of the track list" do
      get "/api/v1/tracks", headers: auth_headers

      expect(JSON.parse(response.body)["tracks"].first).not_to have_key("tags")
    end
  end

  describe "DELETE /api/v1/tracks/:id" do
    it "deletes the track" do
      track = create(:track, album: album, artist: artist, user: user)

      expect {
        delete "/api/v1/tracks/#{track.id}", headers: auth_headers
      }.to change(Track, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns not found for another user's track" do
      other_track = create(:track)

      delete "/api/v1/tracks/#{other_track.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/tracks/:id/stream" do
    it "returns the audio file URL" do
      track = create(:track, album: album, artist: artist, user: user)

      get "/api/v1/tracks/#{track.id}/stream", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["url"]).to be_present
      expect(json["content_type"]).to eq("audio/mpeg")
    end

    it "returns not found for a track without audio" do
      track = create(:track, :youtube, album: album, artist: artist, user: user)

      get "/api/v1/tracks/#{track.id}/stream", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
