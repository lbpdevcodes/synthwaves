require "rails_helper"

RSpec.describe FolderCard::Component, type: :component do
  include ViewComponent::TestHelpers

  let(:user) { create(:user) }
  let(:folder) { create(:folder, user: user, name: "My Show") }

  def render_component(folder:)
    render_inline(described_class.new(folder: folder))
  end

  it "renders the folder name" do
    html = render_component(folder: folder)
    expect(html.text).to include("My Show")
  end

  def count_line(html)
    html.at_css(".collection-card-body p")&.text&.strip
  end

  it "counts its videos on the card body, which list mode still shows" do
    create_list(:video, 2, user: user, folder: folder)

    expect(count_line(render_component(folder: folder))).to eq("2 videos")
  end

  it "counts a single video in the singular" do
    create(:video, user: user, folder: folder)

    expect(count_line(render_component(folder: folder))).to eq("1 video")
  end

  it "counts seasons and videos together" do
    create(:video, user: user, folder: folder, season_number: 1)
    create(:video, user: user, folder: folder, season_number: 2)

    expect(count_line(render_component(folder: folder))).to eq("2 seasons · 2 videos")
  end

  it "says it is empty when it holds no videos" do
    expect(count_line(render_component(folder: folder))).to eq("Empty")
  end

  it "counts the collections inside, so a collection of collections isn't empty" do
    create(:folder, user: user, parent: folder, name: "Season 1")

    expect(count_line(render_component(folder: folder))).to eq("1 collection")
  end

  it "counts collections before seasons and videos" do
    create(:folder, user: user, parent: folder, name: "Specials")
    create(:video, user: user, folder: folder, season_number: 1)
    create(:video, user: user, folder: folder, season_number: 2)

    expect(count_line(render_component(folder: folder))).to eq("1 collection · 2 seasons · 2 videos")
  end

  it "names the collection it sits in, when asked" do
    south_park = create(:folder, user: user, parent: folder, name: "South Park")
    create_list(:video, 3, user: user, folder: south_park)

    html = render_inline(described_class.new(folder: south_park, show_parent: true))

    expect(count_line(html)).to eq("in My Show · 3 videos")
  end

  it "draws a stacked edge behind the card so it reads as a collection" do
    html = render_component(folder: folder)

    expect(html.css(".collection-card-stack").size).to eq(2)
  end

  it "links to folder show page" do
    html = render_component(folder: folder)
    link = html.at_css("a.collection-card")
    expect(link["href"]).to eq("/folders/#{folder.id}")
  end

  it "offers an edit pencil beside the card link that opens in the modal" do
    html = render_component(folder: folder)

    edit = html.at_css("a[href='/folders/#{folder.id}/edit']")
    expect(edit["data-turbo-frame"]).to eq("modal")
    expect(edit["aria-label"]).to eq("Edit My Show")
    expect(edit.ancestors("a")).to be_empty
  end

  it "shows folder icon when no thumbnails" do
    html = render_component(folder: folder)
    expect(html.at_css(".collection-card-image svg")).to be_present
  end

  it "includes collection-card class for view toggle support" do
    html = render_component(folder: folder)
    expect(html.at_css(".collection-card")).to be_present
  end
end
