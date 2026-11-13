require "rails_helper"

RSpec.describe "Video stats", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /stats/videos" do
    context "with a video library" do
      before do
        create(:video, user: user, duration: 7200.0, file_size: 3 * 1024**3, year: 1999, genre_names: "crime", width: 3840, height: 2160)
        create(:video, :in_folder, user: user, duration: 1800.0, file_size: 1024**3, year: 2004, genre_names: "crime, comedy")
      end

      it "shows the user's video figures" do
        get video_stats_path
        expect(%w[Videos Movies TV\ Episodes Other Collections Total\ Runtime Avg\ Length Library\ Size].map { |label| tile_value(label) })
          .to eq(["2", "1", "1", "0", "1", "2h 30m", "1h 15m", "4 GB"])
      end

      it "charts the videos by genre" do
        get video_stats_path
        expect([bar("Genres", "crime"), bar("Genres", "comedy")]).to eq([["2", "width: 100%"], ["1", "width: 50%"]])
      end

      it "charts the videos by decade" do
        get video_stats_path
        expect([bar("By Decade", "1990s"), bar("By Decade", "2000s")]).to eq([["1", "width: 100%"], ["1", "width: 100%"]])
      end

      it "charts the videos by resolution" do
        get video_stats_path
        expect([bar("By Resolution", "4K"), bar("By Resolution", "1080p")]).to eq([["1", "width: 100%"], ["1", "width: 100%"]])
      end
    end

    context "with no videos" do
      it "shows zeros and no charts" do
        get video_stats_path
        expect(tile_value("Videos")).to eq("0")
        expect(response.body).not_to include("Genres", "By Decade", "By Resolution")
      end
    end

    it "links back to the music stats" do
      get video_stats_path
      expect(stats_page.css("a").find { |link| link.text.strip == "Music" }&.[]("href")).to eq(stats_path)
    end

    it "switches in place, so going back and forth stacks no history" do
      get video_stats_path
      switch = stats_page.css("a").select { |link| %w[Music Video].include?(link.text.strip) }
      expect(switch.map { |link| link["data-turbo-action"] }).to eq(%w[replace replace])
    end

    it "marks Video as the stats being shown" do
      get video_stats_path
      expect(stats_page.at_css("a[aria-current=page]").text.strip).to eq("Video")
    end

    context "without authentication" do
      it "redirects to login" do
        delete session_path
        get video_stats_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
