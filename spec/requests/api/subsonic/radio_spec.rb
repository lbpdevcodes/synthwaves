require "rails_helper"

RSpec.describe "Subsonic Radio API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /api/rest/getInternetRadioStations.view" do
    it "returns stream-type external streams" do
      create(:external_stream, :stream, user: user, name: "Jazz FM", stream_url: "https://jazz.example.com/stream")

      get "/api/rest/getInternetRadioStations.view", params: auth_params

      body = response.parsed_body
      stations = body.dig("subsonic-response", "internetRadioStations", "internetRadioStation")
      expect(stations.size).to eq(1)
      expect(stations.first["name"]).to eq("Jazz FM")
      expect(stations.first["streamUrl"]).to eq("https://jazz.example.com/stream")
    end

    it "excludes youtube-type external streams" do
      create(:external_stream, user: user, source_type: "youtube")

      get "/api/rest/getInternetRadioStations.view", params: auth_params

      body = response.parsed_body
      stations = body.dig("subsonic-response", "internetRadioStations", "internetRadioStation")
      expect(stations).to be_empty
    end

    it "does not return another user's stations" do
      other_user = create(:user)
      create(:external_stream, :stream, user: other_user, name: "Other Radio")

      get "/api/rest/getInternetRadioStations.view", params: auth_params

      body = response.parsed_body
      stations = body.dig("subsonic-response", "internetRadioStations", "internetRadioStation")
      expect(stations).to be_empty
    end
  end
end
