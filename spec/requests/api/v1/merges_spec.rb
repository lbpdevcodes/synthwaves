require "rails_helper"

RSpec.describe "API::V1 merges", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:json) { JSON.parse(response.body) }

  describe "POST /api/v1/albums/:id/merge" do
    let(:artist) { create(:artist, user: user) }
    let(:survivor) { create(:album, artist: artist, user: user, title: "Survivor") }
    let(:source) { create(:album, artist: create(:artist, user: user), user: user) }

    it "moves the source's tracks to the survivor and its artist, then removes the source" do
      track = create(:track, album: source, artist: source.artist, user: user)

      post "/api/v1/albums/#{survivor.id}/merge", params: {source_album_id: source.id}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json).to include("id" => survivor.id, "title" => "Survivor", "tracks_count" => 1)
      expect(track.reload).to have_attributes(album_id: survivor.id, artist_id: artist.id)
      expect(Album.exists?(source.id)).to be(false)
    end

    it "answers 404 and keeps the source when the source belongs to another user" do
      foreign = create(:album)

      post "/api/v1/albums/#{survivor.id}/merge", params: {source_album_id: foreign.id}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(Album.exists?(foreign.id)).to be(true)
    end

    it "answers 404 and keeps the source when the survivor belongs to another user" do
      post "/api/v1/albums/#{create(:album).id}/merge", params: {source_album_id: source.id}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(Album.exists?(source.id)).to be(true)
    end

    it "explains why an album can't merge into itself" do
      post "/api/v1/albums/#{survivor.id}/merge", params: {source_album_id: survivor.id}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to eq("Cannot merge an album into itself.")
    end

    it "requires a token" do
      post "/api/v1/albums/#{survivor.id}/merge", params: {source_album_id: source.id}

      expect(response).to have_http_status(:unauthorized)
      expect(Album.exists?(source.id)).to be(true)
    end
  end

  describe "POST /api/v1/artists/:id/merge" do
    let(:survivor) { create(:artist, user: user, name: "Survivor") }
    let(:source) { create(:artist, user: user) }

    it "moves the source's albums and tracks to the survivor, then removes the source" do
      album = create(:album, artist: source, user: user)
      track = create(:track, album: album, artist: source, user: user)

      post "/api/v1/artists/#{survivor.id}/merge", params: {source_artist_id: source.id}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json).to include("id" => survivor.id, "name" => "Survivor", "albums_count" => 1, "tracks_count" => 1)
      expect(track.reload.artist_id).to eq(survivor.id)
      expect(Artist.exists?(source.id)).to be(false)
    end

    it "answers 404 and keeps the source when the source belongs to another user" do
      foreign = create(:artist)

      post "/api/v1/artists/#{survivor.id}/merge", params: {source_artist_id: foreign.id}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(Artist.exists?(foreign.id)).to be(true)
    end

    it "explains why an artist can't merge into itself" do
      post "/api/v1/artists/#{survivor.id}/merge", params: {source_artist_id: survivor.id}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to eq("Cannot merge an artist into itself.")
    end
  end

  describe "POST /api/v1/playlists/:id/merge" do
    let(:survivor) { create(:playlist, user: user, name: "Survivor") }
    let(:source) { create(:playlist, user: user) }

    it "appends the source's tracks to the survivor, then removes the source" do
      track = create(:track, user: user)
      source.add_track(track)

      post "/api/v1/playlists/#{survivor.id}/merge", params: {source_playlist_id: source.id}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json).to include("id" => survivor.id, "name" => "Survivor", "tracks_count" => 1)
      expect(survivor.reload.tracks).to contain_exactly(track)
      expect(Playlist.exists?(source.id)).to be(false)
    end

    it "answers 404 and keeps the source when the source belongs to another user" do
      foreign = create(:playlist)

      post "/api/v1/playlists/#{survivor.id}/merge", params: {source_playlist_id: foreign.id}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(Playlist.exists?(foreign.id)).to be(true)
    end

    it "explains why a playlist can't merge into itself" do
      post "/api/v1/playlists/#{survivor.id}/merge", params: {source_playlist_id: survivor.id}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to eq("Cannot merge a playlist into itself.")
    end
  end
end
