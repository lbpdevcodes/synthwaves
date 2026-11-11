require "rails_helper"

RSpec.describe YoutubeAlbumImportService do
  let(:user) { create(:user) }
  let(:url) { "https://www.youtube.com/playlist?list=PLtest123" }
  let(:tracks) { create_list(:track, 2, user: user) }

  before do
    allow(YoutubePlaylistImportService).to receive(:call)
      .and_return(YoutubeImport.new(title: "Classic Rock Hits", tracks: tracks))
  end

  def import(**options)
    described_class.call(url: url, user: user, **options)
  end

  it "keeps a music playlist's grouping as a library playlist named after it" do
    import

    playlist = user.playlists.find_by!(name: "Classic Rock Hits")
    expect(playlist.tracks.order("playlist_tracks.position")).to eq(tracks)
  end

  it "reuses that playlist when the import is run again" do
    2.times { import }

    expect(user.playlists.where(name: "Classic Rock Hits").count).to eq(1)
  end

  it "reuses a named new playlist when the import is run again" do
    2.times { import(new_playlist_name: "Road Trip") }

    expect(user.playlists.where(name: "Road Trip").count).to eq(1)
  end

  it "returns the import with the playlist the tracks went to" do
    expect(import.playlist).to eq(user.playlists.find_by!(name: "Classic Rock Hits"))
  end
end
