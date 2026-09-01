require "rails_helper"

RSpec.describe ChannelArtistRetag do
  def channel_track(user, title:, channel: "Diego Pradilla")
    artist = create(:artist, user: user, name: channel)
    album = create(:album, user: user, artist: artist)
    create(:track, user: user, artist: artist, album: album, title: title)
  end

  describe "#apply" do
    it "credits the track to the mapped artist and cleans the title" do
      user = create(:user)
      track = channel_track(user, title: "Shakira - Inevitable (Official HD Video)")
      retag = described_class.new({track.id => {"artist" => "Shakira", "title" => "Inevitable"}})

      retag.apply(track)

      expect(track.reload.artist.name).to eq("Shakira")
      expect(track.title).to eq("Inevitable")
    end

    it "leaves the title alone when the entry names no title" do
      user = create(:user)
      track = channel_track(user, title: "MECANO")
      retag = described_class.new({track.id => {"artist" => "Mecano"}})

      retag.apply(track)

      expect(track.reload.artist.name).to eq("Mecano")
      expect(track.title).to eq("MECANO")
    end

    it "reuses an artist that differs only in case instead of creating a duplicate" do
      user = create(:user)
      existing = create(:artist, user: user, name: "CAIFANES")
      track = channel_track(user, title: "CAIFANES//AFUERA")
      retag = described_class.new({track.id => {"artist" => "Caifanes", "title" => "Afuera"}})

      expect { retag.apply(track) }.not_to change(Artist, :count)
      expect(track.reload.artist).to eq(existing)
    end

    it "creates the artist when the user has none by that name" do
      user = create(:user)
      track = channel_track(user, title: "Selena - Amor Prohibido")
      retag = described_class.new({track.id => {"artist" => "Selena", "title" => "Amor Prohibido"}})

      expect { retag.apply(track) }.to change { user.artists.count }.by(1)
      expect(track.reload.artist.name).to eq("Selena")
    end

    it "never borrows another user's artist" do
      user = create(:user)
      create(:artist, user: create(:user), name: "Shakira")
      track = channel_track(user, title: "Shakira - Inevitable")
      retag = described_class.new({track.id => {"artist" => "Shakira", "title" => "Inevitable"}})

      retag.apply(track)

      expect(track.reload.artist.user).to eq(user)
    end

    it "makes no further change on a second run" do
      user = create(:user)
      track = channel_track(user, title: "Selena - Amor Prohibido")
      retag = described_class.new({track.id => {"artist" => "Selena", "title" => "Amor Prohibido"}})
      retag.apply(track)

      expect { retag.apply(track.reload) }.not_to change(Artist, :count)
      expect(track.reload.title).to eq("Amor Prohibido")
    end

    it "raises for a track the mapping does not cover" do
      track = channel_track(create(:user), title: "Anything")

      expect { described_class.new({}).apply(track) }.to raise_error(KeyError)
    end
  end

  describe "#track_ids" do
    it "returns every mapped track id" do
      retag = described_class.new({1 => {"artist" => "A"}, 2 => {"artist" => "B"}})

      expect(retag.track_ids).to contain_exactly(1, 2)
    end
  end

  describe ".load" do
    it "reads the shipped mapping keyed by integer track id" do
      retag = described_class.load

      expect(retag.track_ids).to all(be_an(Integer))
      expect(retag.track_ids.size).to be > 150
    end

    it "names a real artist for every mapped track" do
      entries = described_class.load.entries

      expect(entries.values.map { |e| e["artist"] }).to all(be_present)
    end

    it "never maps a track back to one of the channel names it is repairing" do
      channels = ChannelArtistRetag::CHANNEL_NAMES
      names = described_class.load.entries.values.map { |e| e["artist"] }

      expect(names & channels).to be_empty
    end
  end
end
