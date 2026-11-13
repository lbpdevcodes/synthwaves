require "rails_helper"

RSpec.describe VideoLibrary do
  let(:user) { create(:user) }

  def listed(sort: "added", direction: "desc", **filter)
    library = described_class.new(user: user, filter: VideoFilter.new(**filter), sort: sort, direction: direction)
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

  it "leaves a collection inside another out of the grid" do
    tv = create(:folder, user: user, name: "TV")
    create(:folder, user: user, parent: tv, name: "South Park")

    expect(listed).to eq([tv])
  end

  it "finds a collection inside another by search" do
    tv = create(:folder, user: user, name: "TV")
    south_park = create(:folder, user: user, parent: tv, name: "South Park")

    expect(listed(query: "South")).to eq([south_park])
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

  describe "filtered by type" do
    it "shows only the videos of that type" do
      movie = create(:video, user: user, video_type: "movie")
      create(:video, user: user, video_type: "tv")

      expect(listed(type: "movie")).to eq([movie])
    end

    it "shows the videos with no type as Other" do
      create(:video, user: user, video_type: "movie")
      clip = create(:video, user: user, video_type: nil)

      expect(listed(type: "other")).to eq([clip])
    end

    it "ignores a type it doesn't know" do
      movie = create(:video, user: user, video_type: "movie")

      expect(listed(type: "cartoon")).to eq([movie])
    end

    it "shows a collection only when a video inside it is of that type" do
      star_wars = create(:folder, user: user, name: "Star Wars")
      create(:video, user: user, folder: star_wars, video_type: "movie")
      south_park = create(:folder, user: user, name: "South Park")
      create(:video, user: user, folder: south_park, video_type: "tv")

      expect(listed(type: "movie")).to eq([star_wars])
    end

    it "shows a top-level collection when the match sits two levels down" do
      tv = create(:folder, user: user, name: "TV")
      south_park = create(:folder, user: user, parent: tv, name: "South Park")
      season = create(:folder, user: user, parent: south_park, name: "Season 1")
      create(:video, user: user, folder: season, video_type: "tv")

      expect(listed(type: "tv")).to eq([tv])
    end
  end

  describe "filtered by genre" do
    it "shows only the videos filed under it" do
      comedy = create(:video, user: user, genre_names: "comedy")
      create(:video, user: user, genre_names: "action")

      expect(listed(genre: "comedy")).to eq([comedy])
    end

    it "shows a collection only when a video inside it has the genre" do
      batman = create(:folder, user: user, name: "Batman")
      create(:video, user: user, folder: batman, genre_names: "animated")
      create(:folder, user: user, name: "Star Wars")

      expect(listed(genre: "animated")).to eq([batman])
    end
  end

  describe "sorted by year" do
    it "puts the newest first, counting a collection by its newest video" do
      heat = create(:video, user: user, year: 1995)
      dune = create(:folder, user: user, name: "Dune")
      create(:video, user: user, folder: dune, year: 2021)
      create(:video, user: user, folder: dune, year: 2024)
      matrix = create(:video, user: user, year: 1999)

      expect(listed(sort: "year", direction: "desc")).to eq([dune, matrix, heat])
    end

    it "puts what has no year last, either way round" do
      undated = create(:video, user: user, title: "Zombieland", year: nil)
      heat = create(:video, user: user, year: 1995)
      matrix = create(:video, user: user, year: 1999)

      expect(listed(sort: "year", direction: "desc")).to eq([matrix, heat, undated])
      expect(listed(sort: "year", direction: "asc")).to eq([heat, matrix, undated])
    end
  end
end
