require "rails_helper"

RSpec.describe VideoLibraryBackfill do
  let(:user) { create(:user) }
  let(:backfill) { described_class.new(user, genre_folders: %w[Action Animated]) }

  # The fields the backfill would give this video; {} when it would leave it be.
  def fills(video)
    backfill.changes.find { |change| change.video == video }&.attributes || {}
  end

  describe "the type" do
    it "files a film as a movie" do
      film = create(:video, :untyped, user: user)

      expect(fills(film)).to include(video_type: "movie")
    end

    it "files a numbered episode as TV" do
      episode = create(:video, :untyped, user: user, season_number: 1, episode_number: 2)

      expect(fills(episode)).to include(video_type: "tv")
    end

    it "files an unnumbered special as TV when its collection holds numbered episodes" do
      south_park = create(:folder, user: user, name: "South Park")
      create(:video, user: user, folder: south_park, season_number: 1, episode_number: 1)
      special = create(:video, :untyped, user: user, folder: south_park, title: "X1 South Park Post Covid")

      expect(fills(special)).to include(video_type: "tv")
    end

    it "keeps a loose film a movie when a loose numbered episode sits beside it" do
      create(:video, user: user, episode_number: 1)
      film = create(:video, :untyped, user: user)

      expect(fills(film)).to include(video_type: "movie")
    end

    it "gives a YouTube video no type" do
      clip = create(:video, user: user, youtube_video_id: "dQw4w9WgXcQ")

      expect(fills(clip)).not_to have_key(:video_type)
    end
  end

  describe "the year" do
    def filed_as(filename)
      create(:video, user: user).tap do |video|
        video.file.attach(io: StringIO.new("video"), filename: filename, content_type: "video/mp4")
      end
    end

    it "reads the year from the release name the file was stored under" do
      film = filed_as("Heat.1995.1080p.BluRay.x264.YIFY.mp4")

      expect(fills(film)).to include(year: 1995)
    end

    it "leaves the year blank when the file name has none" do
      film = filed_as("Zombieland.BluRay.1080p.x264.mp4")

      expect(fills(film)).not_to have_key(:year)
    end

    it "leaves the year blank for a video with no file yet" do
      clip = create(:video, user: user)

      expect(fills(clip)).not_to have_key(:year)
    end
  end

  describe "the genre" do
    it "files a video under the genre folder it sits in" do
      action = create(:folder, user: user, name: "Action")
      film = create(:video, user: user, folder: action)

      expect(fills(film)).to include(genre_names: %w[action])
    end

    it "files a video under the nearest genre folder above its collection" do
      animated = create(:folder, user: user, name: "Animated")
      batman = create(:folder, user: user, parent: animated, name: "Batman")
      film = create(:video, user: user, folder: batman)

      expect(fills(film)).to include(genre_names: %w[animated])
    end

    it "gives no genre to a video in a collection outside the genre folders" do
      star_wars = create(:folder, user: user, name: "Star Wars")
      film = create(:video, user: user, folder: star_wars)

      expect(fills(film)).not_to have_key(:genre_names)
    end
  end

  describe "what the video already has" do
    it "keeps the type and year the owner set" do
      episode = create(:video, user: user, video_type: "tv", year: 2000)
      episode.file.attach(io: StringIO.new("video"), filename: "Heat.1995.1080p.mp4", content_type: "video/mp4")

      expect(fills(episode)).not_to include(:video_type, :year)
    end

    it "adds the folder's genre to the genres the video has" do
      action = create(:folder, user: user, name: "Action")
      film = create(:video, user: user, folder: action, genre_names: "crime")

      expect(fills(film)).to include(genre_names: %w[action crime])
    end

    it "leaves out a video with nothing left to fill" do
      action = create(:folder, user: user, name: "Action")
      film = create(:video, user: user, folder: action, video_type: "movie", genre_names: "action")

      expect(backfill.changes.map(&:video)).not_to include(film)
    end
  end

  it "reaches only the owner's videos" do
    create(:video, user: create(:user))

    expect(backfill.changes).to be_empty
  end

  describe "#apply" do
    it "saves what it fills" do
      animated = create(:folder, user: user, name: "Animated")
      film = create(:video, user: user, folder: animated)
      film.file.attach(io: StringIO.new("video"), filename: "Shrek.2001.1080p.BluRay.mp4", content_type: "video/mp4")

      backfill.apply

      expect(film.reload).to have_attributes(video_type: "movie", year: 2001, genre_names: %w[animated])
    end

    it "leaves nothing for a second run to change" do
      action = create(:folder, user: user, name: "Action")
      create(:video, user: user, folder: action)
      create(:video, user: user, episode_number: 1)

      backfill.apply

      expect(described_class.new(user, genre_folders: %w[Action Animated]).changes).to be_empty
    end
  end
end
