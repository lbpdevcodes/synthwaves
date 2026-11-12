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

    it "offers New Folder in the modal instead of Upload Season" do
      get tv_path(tab: "videos")

      new_folder = doc.css("a").find { |a| a.text.strip == "New Folder" }
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

    it "offers both a video upload and a new folder when the library is empty" do
      get tv_path(tab: "videos")

      empty_state = doc.at_css("[data-empty-library]")
      expect(empty_state.at_css("a[href='#{new_video_path}']")["data-turbo-frame"]).to eq("_top")
      expect(empty_state.at_css("a[href='#{new_folder_path}']")["data-turbo-frame"]).to eq("modal")
    end
  end
end
