require "rails_helper"

RSpec.describe VideoCard::Component, type: :component do
  include ViewComponent::TestHelpers

  let(:video) { create(:video, title: "My Video", duration: 125.0, height: 1080) }

  def render_component(video:)
    render_inline(described_class.new(video: video))
  end

  it "renders the video title" do
    html = render_component(video: video)
    expect(html.text).to include("My Video")
  end

  it "renders duration badge" do
    html = render_component(video: video)
    expect(html.text).to include("2:05")
  end

  it "renders resolution label" do
    html = render_component(video: video)
    expect(html.text).to include("1080p")
  end

  it "shows processing indicator" do
    video = create(:video, :processing, title: "Processing Video")
    html = render_component(video: video)
    expect(html.at_css(".animate-spin")).to be_present
  end

  it "shows failed indicator" do
    video = create(:video, :failed, title: "Failed Video")
    html = render_component(video: video)
    expect(html.text).to include("Failed")
  end

  it "links to video show page" do
    html = render_component(video: video)
    link = html.at_css("a.collection-card")
    expect(link["href"]).to eq("/videos/#{video.id}")
  end

  it "draws its actions beside the card link, never inside it" do
    html = render_inline(described_class.new(video: video)) do |card|
      card.with_actions { "<button data-test-action>Move</button>".html_safe }
    end

    action = html.at_css("[data-test-action]")
    expect(action).to be_present
    expect(action.ancestors("a")).to be_empty
  end

  it "includes collection-card class for view toggle support" do
    html = render_component(video: video)
    expect(html.at_css(".collection-card")).to be_present
  end

  context "with show_episode_number" do
    it "shows episode badge when episode_number is present" do
      video = create(:video, title: "The Pilot", episode_number: 3)
      html = render_inline(described_class.new(video: video, show_episode_number: true))
      expect(html.text).to include("E3")
    end

    it "does not show episode badge when show_episode_number is false" do
      video = create(:video, title: "The Pilot", episode_number: 3)
      html = render_inline(described_class.new(video: video, show_episode_number: false))
      expect(html.text).not_to include("E3")
    end

    it "does not show episode badge when episode_number is nil" do
      video = create(:video, title: "The Pilot", episode_number: nil)
      html = render_inline(described_class.new(video: video, show_episode_number: true))
      expect(html.text).not_to include("E")
    end
  end

  describe "image" do
    def attach_image(attachment, name)
      attachment.attach(io: StringIO.new("image"), filename: name, content_type: "image/jpeg")
    end

    def image_sources(video)
      render_component(video: video).css(".collection-card-image img").map { |img| img["src"] }
    end

    it "draws the poster in place of the thumbnail" do
      attach_image(video.thumbnail, "frame.jpg")
      attach_image(video.cover_image, "poster.jpg")

      expect(image_sources(video)).to all(end_with("poster.jpg"))
      expect(image_sources(video)).not_to be_empty
    end

    it "draws the thumbnail when there is no poster" do
      attach_image(video.thumbnail, "frame.jpg")

      expect(image_sources(video)).to eq(image_sources(video).grep(/frame\.jpg\z/))
      expect(image_sources(video).size).to eq(1)
    end
  end

  describe "second line" do
    def second_line(video)
      render_component(video: video).at_css(".collection-card-body p")&.text&.strip
    end

    it "opens with the year" do
      expect(second_line(create(:video, year: 1999, description: "A description"))).to eq("1999 · A description")
    end

    it "is the year alone when there is no description" do
      expect(second_line(create(:video, year: 1999))).to eq("1999")
    end
  end

  context "with show_folder" do
    let(:user) { create(:user) }

    def second_line(video, show_folder: true)
      html = render_inline(described_class.new(video: video, show_folder: show_folder))
      html.at_css(".collection-card-body p")&.text&.strip
    end

    def episode(folder_name, **attrs)
      create(:video, user: user, description: "A description", folder: create(:folder, user: user, name: folder_name), **attrs)
    end

    it "names the collection with the season and episode" do
      expect(second_line(episode("South Park", season_number: 3, episode_number: 2))).to eq("South Park · S3E2")
    end

    it "names the collection with the episode alone when there is no season" do
      expect(second_line(episode("Batman", episode_number: 2))).to eq("Batman · E2")
    end

    it "names the collection alone when the video has no episode number" do
      expect(second_line(episode("Batman"))).to eq("Batman")
    end

    it "keeps the description for a video in no collection" do
      expect(second_line(create(:video, user: user, description: "A description"))).to eq("A description")
    end

    it "keeps the description when the option is off" do
      expect(second_line(episode("Batman"), show_folder: false)).to eq("A description")
    end
  end
end
