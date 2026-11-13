require "rails_helper"

RSpec.describe "Stats", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  # The figure drawn above a tile's label.
  def tile_value(label)
    page.css("div").find { |node| node.text.strip == label && node.element_children.empty? }
      &.previous_element&.text&.strip
  end

  # The [count, bar width] a bar chart under a heading draws for a label.
  def bar(heading, label)
    rows = page.css("h2, h3").find { |node| node.text.strip == heading }.next_element
    row = rows.css("span").find { |span| span.text.strip == label }.parent
    [row.css("span").last.text.strip, row.at_css("[style]")["style"]]
  end

  def page = Nokogiri::HTML(response.body)

  describe "GET /stats" do
    context "with a music library" do
      let(:artist) { create(:artist, user: user) }

      before do
        synthwave = create(:album, artist: artist, genre: "Synthwave")
        create_list(:track, 2, album: synthwave, duration: 180.0, file_size: 5_000_000)
        create(:track, album: create(:album, artist: artist, genre: "Rock"), duration: 180.0, file_size: 5_000_000)
      end

      it "counts the tracks, albums and artists" do
        get stats_path
        expect([tile_value("Tracks"), tile_value("Albums"), tile_value("Artists")]).to eq(%w[3 2 1])
      end

      it "shows the total duration, average track length and library size" do
        get stats_path
        expect([tile_value("Total Duration"), tile_value("Avg Track Length"), tile_value("Library Size")])
          .to eq(["9m", "3m", "14.3 MB"])
      end

      it "draws a bar per genre in the library at its share of the largest" do
        get stats_path
        expect([bar("Genres in Library", "Synthwave"), bar("Genres in Library", "Rock")])
          .to eq([["2", "width: 100%"], ["1", "width: 50%"]])
      end

      it "leaves the library out when only the listening stats are asked for" do
        get stats_path(range: :week), headers: {"Turbo-Frame" => "stats-content"}
        expect(response.body).to include("Total Plays")
        expect(response.body).not_to include("Your Library")
      end
    end

    it "returns success" do
      get stats_path
      expect(response).to have_http_status(:ok)
    end

    it "displays summary cards" do
      get stats_path
      expect(response.body).to include("Total Plays")
      expect(response.body).to include("Listening Time")
      expect(response.body).to include("Current Streak")
      expect(response.body).to include("Longest Streak")
    end

    it "displays time range selector" do
      get stats_path
      expect(response.body).to include("Week")
      expect(response.body).to include("Month")
      expect(response.body).to include("Year")
      expect(response.body).to include("All Time")
    end

    it "defaults to month range" do
      get stats_path
      expect(response.body).to include("Listening Stats")
    end

    it "accepts a range parameter" do
      get stats_path(range: :week)
      expect(response).to have_http_status(:ok)
    end

    it "falls back to month for invalid range" do
      get stats_path(range: :invalid)
      expect(response).to have_http_status(:ok)
    end

    context "with play history" do
      let(:artist) { create(:artist, name: "Neon Dreams") }
      let(:album) { create(:album, artist: artist, genre: "Synthwave") }
      let(:track) { create(:track, album: album, artist: artist, title: "Laser Highway") }

      before do
        3.times { create(:play_history, user: user, track: track, played_at: 1.day.ago) }
      end

      it "shows top tracks" do
        get stats_path
        expect(response.body).to include("Laser Highway")
        expect(response.body).to include("Top Tracks")
      end

      it "shows top artists" do
        get stats_path
        expect(response.body).to include("Neon Dreams")
        expect(response.body).to include("Top Artists")
      end

      it "shows top genres" do
        get stats_path
        expect(response.body).to include("Synthwave")
        expect(response.body).to include("Top Genres")
      end

      it "shows play count in summary" do
        get stats_path
        expect(response.body).to include("3")
      end

      it "fills the listening tiles" do
        get stats_path
        expect(%w[Total\ Plays Listening\ Time Current\ Streak Longest\ Streak].map { |label| tile_value(label) })
          .to eq(["3", "9m", "1 days", "1 days"])
      end

      it "draws a bar per genre played with its play count" do
        get stats_path
        expect(bar("Top Genres", "Synthwave")).to eq(["3", "width: 100%"])
      end
    end

    context "with no play history" do
      it "shows empty state for tracks" do
        get stats_path
        expect(response.body).to include("No plays yet")
      end
    end

    context "without authentication" do
      it "redirects to login" do
        delete session_path
        get stats_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
