require "rails_helper"

RSpec.describe YoutubeImportJob, type: :job do
  let(:user) { create(:user, youtube_api_key: "test_api_key") }

  it "calls YoutubePlaylistImportService with the url, category, and user api_key" do
    allow(YoutubePlaylistImportService).to receive(:call)

    described_class.perform_now(
      "https://www.youtube.com/playlist?list=PLtest123",
      category: "podcast",
      user_id: user.id
    )

    expect(YoutubePlaylistImportService).to have_received(:call)
      .with("https://www.youtube.com/playlist?list=PLtest123", category: "podcast", api_key: "test_api_key", user: user, artist: nil)
  end

  describe "playlist association" do
    let(:artist) { create(:artist, user: user) }
    let(:album) { create(:album, artist: artist, user: user) }
    let!(:track1) { create(:track, album: album, artist: artist, user: user, youtube_video_id: "vid1", track_number: 1) }
    let!(:track2) { create(:track, album: album, artist: artist, user: user, youtube_video_id: "vid2", track_number: 2) }

    before do
      allow(YoutubePlaylistImportService).to receive(:call).and_return(album)
    end

    it "adds tracks to an existing playlist" do
      playlist = create(:playlist, user: user)

      described_class.perform_now(
        "https://www.youtube.com/playlist?list=PLtest123",
        user_id: user.id,
        playlist_id: playlist.id
      )

      expect(playlist.tracks.order(:track_number)).to eq([track1, track2])
    end

    it "creates a new playlist and adds tracks when new_playlist_name is given" do
      expect {
        described_class.perform_now(
          "https://www.youtube.com/playlist?list=PLtest123",
          user_id: user.id,
          new_playlist_name: "My Import"
        )
      }.to change(Playlist, :count).by(1)

      playlist = Playlist.last
      expect(playlist.name).to eq("My Import")
      expect(playlist.tracks.order(:track_number)).to eq([track1, track2])
    end

    it "does not add tracks to a playlist when neither param is set" do
      expect {
        described_class.perform_now(
          "https://www.youtube.com/playlist?list=PLtest123",
          user_id: user.id
        )
      }.not_to change(PlaylistTrack, :count)
    end

    it "skips duplicate tracks already in the playlist" do
      playlist = create(:playlist, user: user)
      create(:playlist_track, playlist: playlist, track: track1, position: 1)

      described_class.perform_now(
        "https://www.youtube.com/playlist?list=PLtest123",
        user_id: user.id,
        playlist_id: playlist.id
      )

      expect(playlist.playlist_tracks.count).to eq(2)
      expect(playlist.tracks).to include(track1, track2)
    end
  end

  describe "audio download enqueueing" do
    let(:artist) { create(:artist, user: user) }
    let(:album) { create(:album, artist: artist, user: user) }

    before do
      allow(YoutubePlaylistImportService).to receive(:call).and_return(album)
    end

    it "enqueues a MediaDownloadJob for each YouTube track without audio when download is true" do
      create(:track, :youtube, album: album, artist: artist, user: user, youtube_video_id: "vid1")
      create(:track, album: album, artist: artist, user: user, youtube_video_id: nil)
      create(:track, album: album, artist: artist, user: user)

      expect {
        described_class.perform_now(
          "https://www.youtube.com/playlist?list=PLtest123",
          download: true,
          user_id: user.id
        )
      }.to have_enqueued_job(MediaDownloadJob).once
        .with(anything, "https://www.youtube.com/watch?v=vid1", user_id: user.id)
    end

    it "does not enqueue downloads by default" do
      create(:track, :youtube, album: album, artist: artist, user: user, youtube_video_id: "vid1")

      expect {
        described_class.perform_now(
          "https://www.youtube.com/playlist?list=PLtest123",
          user_id: user.id
        )
      }.not_to have_enqueued_job(MediaDownloadJob)
    end
  end
end
