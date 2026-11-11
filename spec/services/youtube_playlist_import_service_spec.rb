require "rails_helper"

RSpec.describe YoutubePlaylistImportService do
  let(:api_key) { "test_api_key" }
  let(:user) { create(:user) }

  describe ".call" do
    it "raises error for invalid playlist URL" do
      expect { described_class.call("https://www.youtube.com/watch?v=abc", api_key: api_key, user: user) }
        .to raise_error(YoutubePlaylistImportService::Error, "Invalid YouTube playlist URL")
    end

    context "with music" do
      let(:url) { "https://www.youtube.com/playlist?list=PLtest123" }

      it "credits a video's release note: its artist, its album and its year" do
        stub_playlist_api_calls(
          owner: "Rock Collection", playlist_title: "Classic Rock Hits",
          track_titles: ["The Chain (2004 Remaster)", "Song 2"],
          video_channels: ["Fleetwood Mac - Topic", "Test Channel"],
          descriptions: [file_fixture("youtube/release_note_fleetwood_mac_the_chain.txt").read, nil]
        )

        described_class.call(url, api_key: api_key, user: user)

        track = user.tracks.find_by!(youtube_video_id: "vid1")
        expect(track).to have_attributes(title: "The Chain (2004 Remaster)", release_year: 1977)
        expect(track.artist.name).to eq("Fleetwood Mac")
        expect(track.album).to have_attributes(title: "Rumours", artist: track.artist)
      end

      it "files a video no source names an album for under its artist's Singles" do
        stub_playlist_api_calls(track_titles: ["Daft Punk - Da Funk", "Song 2"])

        described_class.call(url, api_key: api_key, user: user)

        track = user.tracks.find_by!(youtube_video_id: "vid1")
        expect(track.album).to have_attributes(title: "Singles", artist: track.artist)
      end

      it "credits a video naming no artist to its own channel, never the playlist owner" do
        stub_playlist_api_calls(owner: "Rock Collection", video_channels: ["Eagles", "Eagles"])

        described_class.call(url, api_key: api_key, user: user)

        expect(user.tracks.map { |track| track.artist.name }.uniq).to eq(["Eagles"])
      end

      it "parses the artist and title from 'Artist - Song' video titles" do
        stub_playlist_api_calls(
          track_titles: ["Daft Punk - Around The World (Official Video)", "Kraftwerk - Trans-Europe Express"]
        )

        described_class.call(url, api_key: api_key, user: user)

        expect(user.tracks.find_by!(youtube_video_id: "vid1").title).to eq("Around The World")
        expect(user.tracks.map { |track| track.artist.name }).to contain_exactly("Daft Punk", "Kraftwerk")
      end

      it "creates music artists" do
        stub_playlist_api_calls

        described_class.call(url, api_key: api_key, user: user)

        expect(user.artists).to all(be_music)
      end

      it "returns the imported tracks in playlist order under the playlist's title" do
        stub_playlist_api_calls(track_titles: ["Daft Punk - Da Funk", "Kraftwerk - Computer Love"])

        import = described_class.call(url, api_key: api_key, user: user)

        expect(import.title).to eq("Test Playlist")
        expect(import.tracks.map(&:youtube_video_id)).to eq(%w[vid1 vid2])
      end

      it "skips videos it has already imported" do
        stub_playlist_api_calls

        described_class.call(url, api_key: api_key, user: user)
        import = described_class.call(url, api_key: api_key, user: user)

        expect(import.tracks.size).to eq(2)
        expect(Track.where(youtube_video_id: "vid1").count).to eq(1)
      end

      context "when the playlist is one artist's full album" do
        let(:playlist_title) { "Carlos Vives - El Amor De Mi Tierra (Full Album)" }

        it "files the tracks in an album named after the playlist, numbered in playlist order" do
          stub_playlist_api_calls(playlist_title: playlist_title)

          import = described_class.call(url, api_key: api_key, user: user)

          expect(import.tracks.map { |track| track.album.title }.uniq).to eq([playlist_title])
          expect(import.tracks.map(&:track_number)).to eq([1, 2])
        end

        it "keeps the playlist URL and thumbnail on that album" do
          stub_playlist_api_calls(playlist_title: playlist_title)

          import = described_class.call(url, api_key: api_key, user: user)

          album = import.tracks.first.album
          expect(album.youtube_playlist_url).to eq(url)
          expect(album.cover_image).to be_attached
        end
      end
    end

    context "with podcasts" do
      let(:url) { "https://www.youtube.com/playlist?list=PLtest123" }

      def import_podcast
        described_class.call(url, category: "podcast", api_key: api_key, user: user)
      end

      def playlist_album
        user.albums.find_by!(title: "Test Playlist")
      end

      it "files every episode in an album named after the playlist, under the channel" do
        stub_playlist_api_calls

        import_podcast

        expect(playlist_album.artist.name).to eq("Test Channel")
        expect(playlist_album.tracks.count).to eq(2)
        expect(playlist_album.tracks.find_by(youtube_video_id: "vid1"))
          .to have_attributes(title: "Song 1", track_number: 1, duration: 225.0)
        expect(playlist_album.tracks.find_by(youtube_video_id: "vid2"))
          .to have_attributes(title: "Song 2", track_number: 2)
      end

      it "creates a podcast artist" do
        stub_playlist_api_calls

        import_podcast

        expect(playlist_album.artist).to be_podcast
      end

      it "does not overwrite an existing artist's category" do
        create(:artist, user: user, name: "Test Channel", category: "music")
        stub_playlist_api_calls

        import_podcast

        expect(playlist_album.artist).to be_music
      end

      it "credits a parsed artist when an episode title reads 'Artist - Song'" do
        stub_playlist_api_calls(track_titles: ["Daft Punk - Da Funk", "Just A Song Title"])

        import_podcast

        expect(user.tracks.find_by!(youtube_video_id: "vid1").artist.name).to eq("Daft Punk")
        expect(user.tracks.find_by!(youtube_video_id: "vid2").artist.name).to eq("Test Channel")
      end

      it "skips episodes it has already imported" do
        stub_playlist_api_calls

        import_podcast
        import_podcast

        expect(playlist_album.tracks.count).to eq(2)
        expect(Track.where(youtube_video_id: "vid1").count).to eq(1)
      end

      it "saves youtube_playlist_url on the album" do
        stub_playlist_api_calls

        import_podcast

        expect(playlist_album.youtube_playlist_url).to eq(url)
      end

      it "does not overwrite existing youtube_playlist_url on re-import" do
        stub_playlist_api_calls
        import_podcast
        playlist_album.update!(youtube_playlist_url: "https://www.youtube.com/playlist?list=PLoriginal")

        import_podcast

        expect(playlist_album.youtube_playlist_url).to eq("https://www.youtube.com/playlist?list=PLoriginal")
      end

      it "downloads and attaches the thumbnail" do
        stub_playlist_api_calls

        import_podcast

        expect(playlist_album.cover_image).to be_attached
      end
    end
  end

  context "without API key (yt-dlp fallback)" do
    let(:api_key) { nil }
    let(:url) { "https://www.youtube.com/playlist?list=PLtest123" }

    it "imports a playlist using yt-dlp metadata" do
      stub_ytdlp_playlist_metadata

      import = described_class.call(url, api_key: api_key, user: user)

      expect(import.tracks.map(&:title)).to eq(["Song 1", "Song 2"])
      expect(import.tracks.first.duration).to eq(225.0)
    end

    it "credits each video's own channel, never the playlist owner" do
      stub_ytdlp_playlist_metadata

      import = described_class.call(url, api_key: api_key, user: user)

      expect(import.tracks.map { |track| track.artist.name }.uniq).to eq(["Video Channel"])
    end

    it "does not call YoutubeAPIService" do
      stub_ytdlp_playlist_metadata

      expect(YoutubeAPIService).not_to receive(:new)

      described_class.call(url, api_key: api_key, user: user)
    end

    it "parses artist from track titles" do
      stub_ytdlp_playlist_metadata(track_titles: ["Daft Punk - Around The World", "Kraftwerk - Trans-Europe Express"])

      described_class.call(url, api_key: api_key, user: user)

      track1 = user.tracks.find_by!(youtube_video_id: "vid1")
      expect(track1.artist.name).to eq("Daft Punk")
      expect(track1.title).to eq("Around The World")
    end

    it "saves youtube_playlist_url on a podcast album" do
      stub_ytdlp_playlist_metadata

      described_class.call(url, category: "podcast", api_key: api_key, user: user)

      expect(user.albums.find_by!(title: "Test Playlist").youtube_playlist_url).to eq(url)
    end

    it "returns nil when playlist has no entries" do
      stub_ytdlp_playlist_metadata(track_titles: [])

      expect(described_class.call(url, api_key: api_key, user: user)).to be_nil
    end
  end

  private

  def stub_ytdlp_playlist_metadata(track_titles: ["Song 1", "Song 2"])
    entries = track_titles.each_with_index.map do |title, index|
      {"id" => "vid#{index + 1}", "title" => title, "duration" => 225.0, "channel" => "Video Channel"}
    end

    json = {
      id: "PLtest123",
      title: "Test Playlist",
      channel: "Test Channel",
      uploader: "Test Channel",
      thumbnails: [
        {"url" => "https://i.ytimg.com/vi/abc/hqdefault.jpg", "preference" => 5}
      ],
      entries: entries
    }.to_json

    allow(Open3).to receive(:capture3).with(
      "yt-dlp", "--flat-playlist", "--dump-single-json", "--no-download",
      "https://www.youtube.com/playlist?list=PLtest123"
    ).and_return([json, "", instance_double(Process::Status, success?: true)])

    stub_request(:get, "https://i.ytimg.com/vi/abc/hqdefault.jpg")
      .to_return(status: 200, body: "fake_image_data", headers: {"Content-Type" => "image/jpeg"})
  end

  # The playlist's owner and each video's own channel are separate on YouTube:
  # "Rock Collection" owns a playlist of videos uploaded by "Boston - Topic".
  def stub_playlist_api_calls(track_titles: ["Song 1", "Song 2"], playlist_title: "Test Playlist",
    owner: "Test Channel", video_channels: ["Test Channel", "Test Channel"], descriptions: [nil, nil])
    title1, title2 = track_titles

    stub_request(:get, "https://www.googleapis.com/youtube/v3/playlists")
      .with(query: hash_including(id: "PLtest123"))
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {
          items: [{
            snippet: {
              title: playlist_title,
              channelTitle: owner,
              thumbnails: {high: {url: "https://i.ytimg.com/vi/abc/hqdefault.jpg"}}
            },
            contentDetails: {itemCount: 2}
          }]
        }.to_json
      )

    stub_request(:get, "https://www.googleapis.com/youtube/v3/playlistItems")
      .with(query: hash_including(playlistId: "PLtest123"))
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {
          items: [
            {snippet: {resourceId: {videoId: "vid1"}, title: title1, position: 0, thumbnails: {}}},
            {snippet: {resourceId: {videoId: "vid2"}, title: title2, position: 1, thumbnails: {}}}
          ]
        }.to_json
      )

    stub_request(:get, "https://www.googleapis.com/youtube/v3/videos")
      .with(query: hash_including(id: "vid1,vid2"))
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {
          items: [
            {id: "vid1", snippet: {title: title1, channelTitle: video_channels[0], description: descriptions[0]},
             contentDetails: {duration: "PT3M45S"}},
            {id: "vid2", snippet: {title: title2, channelTitle: video_channels[1], description: descriptions[1]},
             contentDetails: {duration: "PT4M10S"}}
          ]
        }.to_json
      )

    # Stub thumbnail download (may or may not be called)
    stub_request(:get, "https://i.ytimg.com/vi/abc/hqdefault.jpg")
      .to_return(status: 200, body: "fake_image_data", headers: {"Content-Type" => "image/jpeg"})
  end
end
