require "rails_helper"

RSpec.describe "API::V1::PlaylistTrackOrders", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:artist) { create(:artist, user: user) }
  let(:album) { create(:album, artist: artist, user: user) }
  let(:playlist) { create(:playlist, user: user) }

  describe "PATCH /api/v1/playlists/:playlist_id/track_order" do
    it "reorders tracks" do
      tracks = create_list(:track, 3, artist: artist, album: album, user: user)
      pts = tracks.map { |t| playlist.add_track(t) }

      # Reverse the order
      reversed_ids = pts.reverse.map(&:id)

      patch "/api/v1/playlists/#{playlist.id}/track_order",
        params: {playlist_track_ids: reversed_ids},
        headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["reordered"]).to eq(3)

      # Verify positions
      pts.each(&:reload)
      expect(pts[0].position).to eq(3)
      expect(pts[1].position).to eq(2)
      expect(pts[2].position).to eq(1)
    end

    it "returns error without playlist_track_ids" do
      patch "/api/v1/playlists/#{playlist.id}/track_order", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    context "when the list isn't exactly the playlist's entries" do
      let!(:entries) { create_list(:track, 3, artist: artist, album: album, user: user).map { |t| playlist.add_track(t) } }

      def expect_refusal_of(ids)
        patch "/api/v1/playlists/#{playlist.id}/track_order", params: {playlist_track_ids: ids}, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to eq("playlist_track_ids must list every entry in the playlist once")
        expect(entries.map { |entry| entry.reload.position }).to eq([1, 2, 3])
      end

      it "refuses a partial list" do
        expect_refusal_of(entries.first(2).reverse.map(&:id))
      end

      it "refuses a repeated entry" do
        expect_refusal_of([entries[0].id, entries[0].id, entries[1].id])
      end

      it "refuses an entry from another playlist" do
        foreign = create(:playlist, user: user).add_track(create(:track, artist: artist, album: album, user: user))

        expect_refusal_of([entries[0].id, entries[1].id, foreign.id])
      end
    end

    it "returns not found for another user's playlist" do
      other_playlist = create(:playlist)

      patch "/api/v1/playlists/#{other_playlist.id}/track_order",
        params: {playlist_track_ids: [1]},
        headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
