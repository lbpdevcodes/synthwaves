require "rails_helper"

RSpec.describe TrackMatcherService do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:new_order) { create(:artist, user: user, name: "New Order") }
  let(:album) { create(:album, user: user, artist: new_order, title: "Power, Corruption & Lies") }

  def match(query, for_user: user)
    described_class.call(user: for_user, query: query)
  end

  it "matches an exact title case-insensitively" do
    track = create(:track, user: user, artist: new_order, album: album, title: "Blue Monday")

    result = match("blue monday")

    expect(result.track).to eq(track)
    expect(result.confidence).to eq("exact")
  end

  it "matches \"Artist - Title\" against the artist name" do
    track = create(:track, user: user, artist: new_order, album: album, title: "Blue Monday")

    result = match("New Order - Blue Monday")

    expect(result.track).to eq(track)
    expect(result.confidence).to eq("exact")
  end

  it "falls back to a partial match when the artist hint is wrong" do
    track = create(:track, user: user, artist: new_order, album: album, title: "Blue Monday")

    result = match("Wrong Artist - Blue Monday")

    expect(result.track).to eq(track)
    expect(result.confidence).to eq("partial")
  end

  it "matches a title substring with partial confidence" do
    track = create(:track, user: user, artist: new_order, album: album, title: "Blue Monday")

    result = match("blue mond")

    expect(result.track).to eq(track)
    expect(result.confidence).to eq("partial")
  end

  it "prefers the artist-matching candidate among partial matches" do
    other_artist = create(:artist, user: user, name: "Other")
    other_album = create(:album, user: user, artist: other_artist, title: "Other Album")
    create(:track, user: user, artist: other_artist, album: other_album, title: "Blue Skies")
    wanted = create(:track, user: user, artist: new_order, album: album, title: "Blue Monday")

    result = match("new order - blue")

    expect(result.track).to eq(wanted)
    expect(result.confidence).to eq("partial")
  end

  it "returns nils when nothing matches" do
    create(:track, user: user, artist: new_order, album: album, title: "Blue Monday")

    result = match("Age of Consent")

    expect(result.track).to be_nil
    expect(result.confidence).to be_nil
  end

  it "uses the artist hint to disambiguate duplicate exact titles" do
    other_artist = create(:artist, user: user, name: "Cover Band")
    other_album = create(:album, user: user, artist: other_artist, title: "Covers")
    create(:track, user: user, artist: other_artist, album: other_album, title: "Blue Monday")
    wanted = create(:track, user: user, artist: new_order, album: album, title: "Blue Monday")

    result = match("New Order - Blue Monday")

    expect(result.track).to eq(wanted)
    expect(result.confidence).to eq("exact")
  end

  it "does not match tracks outside the user's library" do
    foreign_artist = create(:artist, user: other_user, name: "New Order")
    foreign_album = create(:album, user: other_user, artist: foreign_artist, title: "PCL")
    create(:track, user: other_user, artist: foreign_artist, album: foreign_album, title: "Blue Monday")

    result = match("Blue Monday")

    expect(result.track).to be_nil
  end

  it "treats LIKE wildcards in the query literally" do
    create(:track, user: user, artist: new_order, album: album, title: "500 Miles")
    wanted = create(:track, user: user, artist: new_order, album: album, title: "50% Off")

    result = match("50%")

    expect(result.track).to eq(wanted)
    expect(result.confidence).to eq("partial")
  end
end
