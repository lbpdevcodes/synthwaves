require "rails_helper"

RSpec.describe YoutubeTrackAttribution do
  def attribute(title:, description: nil, channel_name: "Some Uploader", playlist_title: "Classic Rock Hits")
    described_class.call(title: title, description: description, channel_name: channel_name,
      playlist_title: playlist_title)
  end

  it "credits a release note's artist, title, album and year" do
    result = attribute(
      title: "The Chain (2004 Remaster)", channel_name: "Fleetwood Mac - Topic",
      description: file_fixture("youtube/release_note_fleetwood_mac_the_chain.txt").read
    )

    expect(result).to have_attributes(
      artist: "Fleetwood Mac", title: "The Chain (2004 Remaster)", album: "Rumours",
      year: 1977, tier: :release_note
    )
  end

  it "trusts an 'Artist - Title' upload whose channel names the same artist" do
    result = attribute(
      title: "Busta Rhymes - Touch It (Official Music Video)", channel_name: "BustaRhymesVEVO",
      description: file_fixture("youtube/vevo_busta_rhymes_touch_it.txt").read
    )

    expect(result).to have_attributes(
      artist: "Busta Rhymes", title: "Touch It", album: nil, year: nil, tier: :channel_confirmed
    )
  end

  it "marks an 'Artist - Title' upload from an unrelated channel as parsed from the title alone" do
    result = attribute(title: "Horace Andy - Got To Be Sure", channel_name: "funko92")

    expect(result).to have_attributes(artist: "Horace Andy", title: "Got To Be Sure", tier: :title_only)
  end

  it "does not let a channel confirm an artist too short to identify it" do
    result = attribute(title: "01 - Intro", channel_name: "nirvana2011fan")

    expect(result.tier).to eq(:title_only)
  end

  it "files a full-album rip under the artist the playlist title names, with the playlist as its album" do
    playlist_title = "Carlos Vives - El Amor De Mi Tierra (Full Album)"
    result = attribute(title: "La Tierra Del Olvido", playlist_title: playlist_title)

    expect(result).to have_attributes(
      artist: "Carlos Vives", title: "La Tierra Del Olvido", album: playlist_title, tier: :playlist
    )
  end

  it "falls back to the video's own channel when nothing names the artist" do
    result = attribute(title: "Double Vision", channel_name: "drumgold23")

    expect(result).to have_attributes(artist: "drumgold23", title: "Double Vision", album: nil, tier: :channel)
  end

  it "drops the ' - Topic' suffix when falling back to an auto-generated channel" do
    result = attribute(title: "Baby Hold On", channel_name: "Eddie Money - Topic")

    expect(result.artist).to eq("Eddie Money")
  end
end
