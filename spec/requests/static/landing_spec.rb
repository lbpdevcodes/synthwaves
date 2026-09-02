require "rails_helper"

RSpec.describe "Static::Landing", type: :request do
  describe "GET /" do
    context "when not authenticated" do
      before { get root_path }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "displays all nine feature cards" do
        expect(response.body).to include("Music Library")
        expect(response.body).to include("Playlists")
        expect(response.body).to include("Stream Anywhere")
        expect(response.body).to include("Live TV")
        expect(response.body).to include("TV Guide & DVR")
        expect(response.body).to include("Podcasts")
        expect(response.body).to include("Internet Radio")
        expect(response.body).to include("Themes")
        expect(response.body).not_to include("AI Assistant")
      end

      it "pitches music ownership in the hero" do
        expect(response.body).to include("Stop renting your music")
        expect(response.body).to include("Start your collection")
      end

      it "shows the true cost of renting as an itemized receipt" do
        expect(response.body).to include("The math of renting")
        expect(response.body).to include("$1,318.80")
        expect(response.body).to include("Songs you own")
        expect(response.body).to include("Take nothing with you")
      end

      it "states the ownership pillars" do
        expect(response.body).to include("Your files, forever")
        expect(response.body).to include("Your server, your rules")
        expect(response.body).to include("Any player you like")
      end

      it "links to the current GitHub repo" do
        expect(response.body).to include("https://github.com/lbpdevcodes/synthwaves")
        expect(response.body).not_to include("leopolicastro/synthwaves.fm")
      end

      it "no longer advertises app stores or the tech stack" do
        expect(response.body).not_to include("Download on the App Store")
        expect(response.body).not_to include("Coming Soon")
        expect(response.body).not_to include("Built with")
      end
    end

    context "when authenticated" do
      let(:user) { User.create!(email_address: "test@example.com", password: "password123") }

      before do
        post session_path, params: {email_address: user.email_address, password: "password123"}
      end

      it "redirects to library" do
        get root_path
        expect(response).to redirect_to(library_path)
      end
    end
  end
end
