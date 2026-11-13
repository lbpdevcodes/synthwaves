require "rails_helper"

RSpec.describe VideoLibraryStats do
  let(:user) { create(:user) }

  subject(:stats) { described_class.new(user: user) }

  context "with no videos" do
    it "counts nothing" do
      expect(%i[video_count movie_count episode_count other_count collection_count total_duration total_file_size average_duration]
        .map { |figure| stats.public_send(figure) }).to all(be_zero)
    end

    it "has no genres, decades or resolutions to chart" do
      expect([stats.genres, stats.decades, stats.resolutions]).to all(eq({}))
    end
  end

  describe "#video_count" do
    it "counts the user's ready videos only" do
      create_list(:video, 2, user: user)
      create(:video, :processing, user: user)
      create(:video, :failed, user: user)
      create(:video)
      expect(stats.video_count).to eq(2)
    end
  end

  describe "counts by type" do
    before do
      create_list(:video, 2, user: user)
      create(:video, :in_folder, user: user)
      create(:video, :untyped, user: user)
      create(:video, :processing, user: user)
    end

    it "counts the ready movies, episodes and videos of neither type" do
      expect([stats.movie_count, stats.episode_count, stats.other_count]).to eq([2, 1, 1])
    end
  end

  describe "#collection_count" do
    it "counts the user's top-level collections, as the Videos grid lists them" do
      show = create(:folder, user: user)
      create(:folder, user: user, parent: show)
      create(:folder, user: user)
      create(:folder)
      expect(stats.collection_count).to eq(2)
    end
  end

  describe "sizes" do
    before do
      create(:video, user: user, duration: 5400.0, file_size: 2_000_000_000)
      create(:video, user: user, duration: 1800.0, file_size: 1_000_000_000)
      create(:video, user: user, duration: nil, file_size: nil)
      create(:video, :processing, user: user, duration: 999.0, file_size: 999)
    end

    it "adds up the ready videos' running time and file size" do
      expect([stats.total_duration, stats.total_file_size]).to eq([7200.0, 3_000_000_000])
    end

    it "averages the running time over the videos that have one" do
      expect(stats.average_duration).to eq(3600.0)
    end
  end

  describe "#genres" do
    it "counts the ready videos under each genre, most first, ties by name" do
      create(:video, user: user, genre_names: "crime, drama")
      create(:video, user: user, genre_names: "drama")
      create(:video, user: user, genre_names: "action")
      create(:video, :processing, user: user, genre_names: "action, comedy")
      expect(stats.genres.to_a).to eq([["drama", 2], ["action", 1], ["crime", 1]])
    end

    it "leaves out other users' videos and the user's tracks under the same genre" do
      create(:video, user: user, genre_names: "drama")
      create(:video, genre_names: "drama")
      create(:tagging, user: user, tag: Tag.find_by!(name: "drama"), taggable: create(:track, user: user))
      expect(stats.genres).to eq("drama" => 1)
    end

    it "keeps the eight biggest genres" do
      create(:video, user: user, genre_names: %w[a b c d e f g h i])
      create(:video, user: user, genre_names: "i")
      expect(stats.genres.keys).to eq(%w[i a b c d e f g])
    end
  end

  describe "#decades" do
    it "counts the ready videos released in each decade, oldest first" do
      [1999, 2008, 1994, 2001].each { |year| create(:video, user: user, year: year) }
      create(:video, user: user, year: nil)
      create(:video, :processing, user: user, year: 1975)
      expect(stats.decades.to_a).to eq([["1990s", 2], ["2000s", 2]])
    end
  end

  describe "#resolutions" do
    it "counts the ready videos at each resolution, biggest first, skipping the empty ones" do
      create(:video, user: user, width: 1280, height: 720)
      create_list(:video, 2, user: user, width: 3840, height: 2160)
      create(:video, user: user, width: 640, height: 480)
      create(:video, user: user, width: nil, height: nil)
      create(:video, :processing, user: user, width: 1920, height: 1080)
      expect(stats.resolutions.to_a).to eq([["4K", 2], ["720p", 1], ["SD", 1]])
    end
  end
end
