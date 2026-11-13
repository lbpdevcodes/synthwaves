require "rails_helper"

RSpec.describe "TV", type: :request do
  describe "GET /tv" do
    it "renders the podcasts tab with podcast artists" do
      user = create(:user)
      login_user(user)
      create(:artist, :podcast, name: "My Great Podcast", user: user)

      get tv_path(tab: "podcasts")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("My Great Podcast")
    end

    it "does not show music artists in the podcasts tab" do
      user = create(:user)
      login_user(user)
      create(:artist, name: "Music Only Band", category: :music, user: user)

      get tv_path(tab: "podcasts")

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Music Only Band")
    end

    context "without Live TV" do
      let(:user) { create(:user) }

      before { login_user(user) }

      def tabs
        Nokogiri::HTML(response.body).css("a[href^='/tv?tab=']").map { |a| a.text.strip }
      end

      it "opens on Videos and offers only the Videos and Podcasts tabs" do
        get tv_path

        expect(tabs).to eq(%w[Videos Podcasts])
        expect(Nokogiri::HTML(response.body).at_css("[data-empty-library]")).to be_present
      end

      it "shows Videos for the old Guide and Recordings tabs" do
        %w[guide recordings].each do |tab|
          get tv_path(tab: tab)

          expect(Nokogiri::HTML(response.body).at_css("[data-empty-library]")).to be_present
        end
      end

      it "no longer answers the channel, guide and recording pages" do
        ["/tv/channels/new", "/tv-guide", "/recordings"].each do |path|
          get path

          expect(response).to have_http_status(:not_found), path
        end
      end

      it "leaves the TV player, its picture-in-picture box and the recordings stream out of the layout" do
        get tv_path

        doc = Nokogiri::HTML(response.body)
        expect(doc.at_css("[data-controller~='hls-player']")).to be_nil
        expect(doc.at_css("#pip-player")).to be_nil
        expect(doc.css("turbo-cable-stream-source").map { |s| s["signed-stream-name"] })
          .not_to include(Turbo::StreamsChannel.signed_stream_name("recordings_#{user.id}"))
      end
    end
  end

  describe "GET /tv?tab=videos" do
    let(:user) { create(:user) }

    before { login_user(user) }

    def doc
      Nokogiri::HTML(response.body)
    end

    it "offers New Collection in the modal instead of Upload Season" do
      get tv_path(tab: "videos")

      new_folder = doc.css("a").find { |a| a.text.strip == "New Collection" }
      expect(new_folder["href"]).to eq(new_folder_path)
      expect(new_folder["data-turbo-frame"]).to eq("modal")
      expect(response.body).not_to include("Upload Season")
    end

    it "gives each loose video a folder menu that submits outside the TV frame" do
      video = create(:video, user: user)
      create(:folder, user: user, name: "The Wire")

      get tv_path(tab: "videos")

      move = doc.css("form[action='#{video_folder_path(video)}']").first
      expect(move.text).to include("The Wire")
      expect(move["data-turbo-frame"]).to eq("_top")
      expect(doc.at_css("form[action='#{folders_path}'] input[name='video_ids[]'][value='#{video.id}']")).to be_present
    end

    it "shows collections and loose videos in the one grid the view toggle switches" do
      create(:folder, user: user, name: "South Park")
      video = create(:video, user: user, title: "Heat")

      get tv_path(tab: "videos")

      grids = doc.css("[data-view-toggle-target='container']")
      expect(grids.size).to eq(1)
      expect(grids.first.at_css("a[href='#{folder_path(Folder.last)}']")).to be_present
      expect(grids.first.at_css("a[href='#{video_path(video)}']")).to be_present
    end

    it "pages collections along with the videos instead of repeating them on every page" do
      folder = create(:folder, user: user, name: "South Park", created_at: 1.year.ago)
      create_list(:video, 24, user: user)
      card = "a.collection-card[href='#{folder_path(folder)}']"

      get tv_path(tab: "videos")
      expect(doc.at_css(card)).to be_nil

      get tv_path(tab: "videos", page: 2)
      expect(doc.at_css(card)).to be_present
    end

    it "answers a page past the end with an empty grid instead of an error" do
      create(:video, user: user, title: "Heat")

      get tv_path(tab: "videos", page: 99)

      expect(response).to have_http_status(:success)
      expect(doc.at_css("a.collection-card")).to be_nil
    end

    it "sorts the grid by date added or by title" do
      create(:video, user: user, title: "Zodiac", created_at: 1.day.ago)
      create(:folder, user: user, name: "Arrival", created_at: 2.days.ago)

      get tv_path(tab: "videos", sort: "title", direction: "asc")

      titles = doc.css("[data-view-toggle-target='container'] h3").map { |h| h.text.strip }
      expect(titles).to eq(%w[Arrival Zodiac])
      expect(doc.css("select[name='sort'] option").map(&:text)).to eq(["Date Added", "Title"])
    end

    it "falls back to newest first for a sort or direction it doesn't know" do
      create(:video, user: user, title: "Arrival", created_at: 2.days.ago)
      create(:video, user: user, title: "Zodiac", created_at: 1.day.ago)

      get tv_path(tab: "videos", sort: "bogus", direction: "sideways")

      expect(response).to have_http_status(:success)
      titles = doc.css("[data-view-toggle-target='container'] h3").map { |h| h.text.strip }
      expect(titles).to eq(%w[Zodiac Arrival])
    end

    it "finds an episode inside a collection and names the collection on its card" do
      folder = create(:folder, user: user, name: "South Park")
      episode = create(:video, user: user, folder: folder, title: "Weight Gain 4000", season_number: 1, episode_number: 2)

      get tv_path(tab: "videos", q: "weight")

      card = doc.at_css("a.collection-card[href='#{video_path(episode)}']")
      expect(card.at_css(".collection-card-body p").text.strip).to eq("South Park · S1E2")
    end

    it "offers both a video upload and a new folder when the library is empty" do
      get tv_path(tab: "videos")

      empty_state = doc.at_css("[data-empty-library]")
      expect(empty_state.at_css("a[href='#{new_video_path}']")["data-turbo-frame"]).to eq("_top")
      expect(empty_state.at_css("a[href='#{new_folder_path}']")["data-turbo-frame"]).to eq("modal")
    end

    context "with a folder inside another" do
      let!(:tv) { create(:folder, user: user, name: "TV") }
      let!(:south_park) { create(:folder, user: user, parent: tv, name: "South Park") }

      it "lists only the top-level folder" do
        get tv_path(tab: "videos")

        expect(doc.at_css("a[href='#{folder_path(tv)}']")).to be_present
        expect(doc.at_css("a[href='#{folder_path(south_park)}']")).to be_nil
      end

      it "finds the inner folder by search, saying where it sits" do
        get tv_path(tab: "videos", q: "South")

        card = doc.at_css("a[href='#{folder_path(south_park)}']")
        expect(card.text).to include("in TV")
      end
    end
  end
end
