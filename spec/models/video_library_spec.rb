require "rails_helper"

RSpec.describe VideoLibrary do
  let(:user) { create(:user) }

  def listed(sort: "added", direction: "desc", query: nil)
    library = described_class.new(user: user, query: query, sort: sort, direction: direction)
    library.records(library.entries)
  end

  it "lists the user's collections and loose ready videos together" do
    folder = create(:folder, user: user)
    video = create(:video, user: user)

    expect(listed).to contain_exactly(folder, video)
  end

  it "leaves a collection's episodes inside it" do
    folder = create(:folder, user: user)
    create(:video, user: user, folder: folder)

    expect(listed).to eq([folder])
  end

  it "leaves out videos that are processing or failed" do
    create(:video, :processing, user: user)
    create(:video, :failed, user: user)

    expect(listed).to be_empty
  end

  it "ranks a collection by its newest video, newest first" do
    folder = create(:folder, user: user, created_at: 5.days.ago)
    create(:video, user: user, folder: folder, created_at: 1.day.ago)
    older = create(:video, user: user, created_at: 3.days.ago)
    newer = create(:video, user: user, created_at: 2.days.ago)

    expect(listed).to eq([folder, newer, older])
  end

  it "ranks an empty collection by the day it was made" do
    video = create(:video, user: user, created_at: 2.days.ago)
    folder = create(:folder, user: user, created_at: 1.hour.ago)

    expect(listed).to eq([folder, video])
  end

  it "sorts by title, ignoring case, with collections among the videos" do
    collateral = create(:video, user: user, title: "Collateral", created_at: 3.days.ago)
    batman = create(:folder, user: user, name: "batman", created_at: 1.day.ago)
    arrival = create(:video, user: user, title: "Arrival", created_at: 2.days.ago)

    expect(listed(sort: "title", direction: "asc")).to eq([arrival, batman, collateral])
  end

  it "breaks a tie in titles by the date added" do
    newer = create(:folder, user: user, name: "Batman", created_at: 1.day.ago)
    older = create(:video, user: user, title: "batman", created_at: 2.days.ago)

    expect(listed(sort: "title", direction: "asc")).to eq([older, newer])
  end

  it "reverses either order for the other direction" do
    older = create(:video, user: user, title: "Arrival", created_at: 2.days.ago)
    newer = create(:folder, user: user, name: "Batman", created_at: 1.day.ago)

    expect(listed(sort: "added", direction: "asc")).to eq([older, newer])
    expect(listed(sort: "title", direction: "desc")).to eq([newer, older])
  end

  it "searches collection names and video titles" do
    south_park = create(:folder, user: user, name: "South Park")
    create(:folder, user: user, name: "Batman")
    park_life = create(:video, user: user, title: "Park Life")
    create(:video, user: user, title: "Heat")

    expect(listed(query: "park")).to contain_exactly(south_park, park_life)
  end

  it "finds a collection's episodes when searching" do
    folder = create(:folder, user: user, name: "South Park")
    episode = create(:video, user: user, folder: folder, title: "Weight Gain 4000")

    expect(listed(query: "weight")).to eq([episode])
  end

  it "skips an entry whose record was deleted after the list was read" do
    kept = create(:video, user: user)
    gone = create(:video, user: user)
    library = described_class.new(user: user)
    entries = library.entries

    gone.destroy

    expect(library.records(entries)).to eq([kept])
  end

  it "leaves out other users' collections and videos" do
    create(:folder)
    create(:video)

    expect(listed).to be_empty
  end
end
