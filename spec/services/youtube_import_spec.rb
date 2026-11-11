require "rails_helper"

RSpec.describe YoutubeImport do
  let(:user) { create(:user) }

  it "names the one album every track landed in" do
    album = create(:album, user: user)
    tracks = create_list(:track, 2, user: user, album: album, artist: album.artist)

    expect(described_class.new(title: "Full Album", tracks: tracks).album).to eq(album)
  end

  it "names no album when the tracks landed in several" do
    tracks = create_list(:track, 2, user: user)

    expect(described_class.new(title: "Classic Rock Hits", tracks: tracks).summary[:album_id]).to be_nil
  end
end
