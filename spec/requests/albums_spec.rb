require "rails_helper"

RSpec.describe "Albums", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /albums" do
    it "puts an edit pencil on each album card that opens the modal" do
      album = create(:album, user: user)
      get albums_path
      link = Nokogiri::HTML(response.body).at_css("a[href='#{edit_album_path(album)}']")
      expect(link["data-turbo-frame"]).to eq("modal")
    end

    it "returns success" do
      create(:album, artist: create(:artist, user: user))
      get albums_path
      expect(response).to have_http_status(:ok)
    end

    it "filters albums by search query" do
      create(:album, title: "Abbey Road", artist: create(:artist, user: user))
      create(:album, title: "Dark Side of the Moon", artist: create(:artist, user: user))

      get albums_path, params: {q: "Abbey"}

      expect(response.body).to include("Abbey Road")
      expect(response.body).not_to include("Dark Side of the Moon")
    end

    it "shows no albums found message when search has no results" do
      create(:album, title: "Abbey Road", artist: create(:artist, user: user))

      get albums_path, params: {q: "Nonexistent"}

      expect(response.body).to include("No albums found")
      expect(response.body).to include("Nonexistent")
    end

    it "sorts albums by recently added (newest first) by default" do
      create(:album, title: "Older Album", artist: create(:artist, user: user), created_at: 2.days.ago)
      create(:album, title: "Newer Album", artist: create(:artist, user: user), created_at: 1.hour.ago)

      get albums_path

      expect(response.body.index("Newer Album")).to be < response.body.index("Older Album")
    end

    it "sorts albums by title descending" do
      create(:album, title: "Zebra Album", artist: create(:artist, user: user))
      create(:album, title: "Alpha Album", artist: create(:artist, user: user))

      get albums_path, params: {sort: "title", direction: "desc"}

      expect(response.body.index("Zebra Album")).to be < response.body.index("Alpha Album")
    end

    it "sorts albums by recently added" do
      create(:album, title: "Older Album", artist: create(:artist, user: user), created_at: 2.days.ago)
      create(:album, title: "Newer Album", artist: create(:artist, user: user), created_at: 1.hour.ago)

      get albums_path, params: {sort: "created_at", direction: "desc"}

      expect(response.body.index("Newer Album")).to be < response.body.index("Older Album")
    end

    it "sorts albums by year" do
      create(:album, title: "Old Album", year: 1970, artist: create(:artist, user: user))
      create(:album, title: "New Album", year: 2020, artist: create(:artist, user: user))

      get albums_path, params: {sort: "year", direction: "desc"}

      expect(response.body.index("New Album")).to be < response.body.index("Old Album")
    end

    it "excludes podcast albums from index" do
      create(:album, title: "Music Album", artist: create(:artist, category: "music", user: user))
      create(:album, title: "Podcast Album", artist: create(:artist, :podcast, user: user))

      get albums_path

      expect(response.body).to include("Music Album")
      expect(response.body).not_to include("Podcast Album")
    end

    it "paginates results" do
      26.times { |i| create(:album, title: "Album #{i.to_s.rjust(2, "0")}", artist: create(:artist, user: user)) }

      get albums_path

      expect(response).to have_http_status(:ok)
    end

    it "renders album links that break out of the turbo frame" do
      create(:album, title: "Turbo Album", artist: create(:artist, user: user))

      get albums_path

      expect(response.body).to include('data-turbo-frame="_top"')
    end
  end

  describe "GET /albums/:id" do
    it "returns success" do
      album = create(:album, artist: create(:artist, user: user))
      get album_path(album)
      expect(response).to have_http_status(:ok)
    end

    it "shows only the library's tracks for an album MusicBrainz knows" do
      artist = create(:artist, user: user)
      album = create(:album, artist: artist, musicbrainz_release_id: "mb-release-1")
      create(:track, album: album, artist: artist, title: "Enjoy the Silence")

      get album_path(album)

      doc = Nokogiri::HTML(response.body)
      expect(doc.text).to include("Enjoy the Silence")
      expect(doc.at_css("turbo-frame#album-tracks-merged")).to be_nil
    end

    it "keeps Play All as the single primary action" do
      album = create(:album, artist: create(:artist, user: user))
      get album_path(album)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("[data-action='play-all#playAll']")).to be_present
      expect(doc.at_css("[data-action='play-all#shuffleAll']")).not_to be_present
    end

    it "groups management actions in an overflow menu" do
      album = create(:album, youtube_playlist_url: "https://www.youtube.com/playlist?list=PLx", artist: create(:artist, user: user))
      get album_path(album)

      doc = Nokogiri::HTML(response.body)
      menu = doc.css("[data-controller~='dropdown']").find { |d| d.text.include?("Export ZIP") }
      expect(menu).to be_present
      expect(menu.text).to include("Fetch cover", "Refresh from YouTube")
    end

    it "groups Edit and Delete in the overflow menu for the owner" do
      album = create(:album, artist: create(:artist, user: user))
      get album_path(album)

      doc = Nokogiri::HTML(response.body)
      menu = doc.css("[data-controller~='dropdown']").find { |d| d.text.include?("Export ZIP") }
      expect(menu).to be_present
      expect(menu.text).to include("Edit", "Delete")
      expect(menu.at_css("a[href='#{edit_album_path(album)}']")["data-turbo-frame"]).to eq("modal")
    end

    it "offers only the owner's own albums to merge" do
      album = create(:album, title: "Mine", artist: create(:artist, user: user))
      create(:album, title: "Sibling Album", artist: album.artist)
      create(:album, title: "Somebody Elses Album")
      get album_path(album)

      expect(response.body).to include("Sibling Album")
      expect(response.body).not_to include("Somebody Elses Album")
    end

    it "does not render the YouTube playlist URL field" do
      album = create(:album, artist: create(:artist, user: user))
      get album_path(album)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("input[name='album[youtube_playlist_url]']")).not_to be_present
    end

    it "sorts by disc/track number by default" do
      album = create(:album, artist: create(:artist, user: user))
      track_b = create(:track, album: album, disc_number: 1, track_number: 2, title: "Beta")
      track_a = create(:track, album: album, disc_number: 1, track_number: 1, title: "Alpha")
      track_c = create(:track, album: album, disc_number: 2, track_number: 1, title: "Charlie")

      get album_path(album)

      expect(response.body.index(track_a.title)).to be < response.body.index(track_b.title)
      expect(response.body.index(track_b.title)).to be < response.body.index(track_c.title)
    end

    it "sorts by created_at desc (newest first)" do
      album = create(:album, artist: create(:artist, user: user))
      old_track = create(:track, album: album, title: "Old Track", created_at: 2.days.ago)
      new_track = create(:track, album: album, title: "New Track", created_at: 1.hour.ago)

      get album_path(album, sort: "created_at", direction: "desc")

      expect(response.body.index(new_track.title)).to be < response.body.index(old_track.title)
    end

    it "sorts by title asc (alphabetical)" do
      album = create(:album, artist: create(:artist, user: user))
      track_z = create(:track, album: album, title: "Zebra")
      track_a = create(:track, album: album, title: "Apple")

      get album_path(album, sort: "title", direction: "asc")

      expect(response.body.index(track_a.title)).to be < response.body.index(track_z.title)
    end

    it "falls back to disc_number for invalid sort column" do
      album = create(:album, artist: create(:artist, user: user))
      track_b = create(:track, album: album, disc_number: 1, track_number: 2, title: "Beta")
      track_a = create(:track, album: album, disc_number: 1, track_number: 1, title: "Alpha")

      get album_path(album, sort: "nonexistent_column")

      expect(response).to have_http_status(:ok)
      expect(response.body.index(track_a.title)).to be < response.body.index(track_b.title)
    end

    it "paginates when more than 24 tracks" do
      album = create(:album, artist: create(:artist, user: user))
      25.times { |i| create(:track, album: album, track_number: i + 1, title: "Track #{(i + 1).to_s.rjust(3, "0")}") }

      get album_path(album)

      expect(response.body).to include("page=2")
    end

    it "displays total play length" do
      album = create(:album, artist: create(:artist, user: user))
      create(:track, album: album, duration: 180.0)
      create(:track, album: album, duration: 60.0)

      get album_path(album)

      expect(response.body).to include("4:00")
    end

    it "does not show pagination nav with 20 or fewer tracks" do
      album = create(:album, artist: create(:artist, user: user))
      5.times { |i| create(:track, album: album, track_number: i + 1) }

      get album_path(album)

      expect(response.body).not_to include("page=2")
    end
  end

  describe "POST /albums/:id/refresh" do
    let(:album) { create(:album, youtube_playlist_url: "https://www.youtube.com/playlist?list=PLtest123", artist: create(:artist, user: user)) }

    it "refreshes episodes and reports new count" do
      create(:track, album: album, youtube_video_id: "vid1")

      allow(YoutubePlaylistImportService).to receive(:call) do
        create(:track, album: album, youtube_video_id: "vid2")
        album
      end

      post refresh_album_path(album)

      expect(YoutubePlaylistImportService).to have_received(:call)
        .with(album.youtube_playlist_url, category: album.artist.category, api_key: user.youtube_api_key, user: user)
      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("1 new episode added")
    end

    it "reports when no new episodes found" do
      allow(YoutubePlaylistImportService).to receive(:call).and_return(album)

      post refresh_album_path(album)

      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("No new episodes found")
    end

    it "redirects with error when album has no youtube_playlist_url" do
      album_without_url = create(:album, youtube_playlist_url: nil, artist: create(:artist, user: user))

      post refresh_album_path(album_without_url)

      expect(response).to redirect_to(album_path(album_without_url))
      follow_redirect!
      expect(response.body).to include("no YouTube playlist URL")
    end

    it "redirects with error when youtube import fails" do
      allow(YoutubePlaylistImportService).to receive(:call)
        .and_raise(YoutubePlaylistImportService::Error, "API quota exceeded")

      post refresh_album_path(album)

      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("Refresh failed: API quota exceeded")
    end
  end

  describe "POST /albums/:id/fetch_cover" do
    it "calls the service and redirects with success notice" do
      album = create(:album, artist: create(:artist, user: user))
      allow(CoverArtSearchService).to receive(:call).with(album).and_return(:itunes)

      post fetch_cover_album_path(album)

      expect(CoverArtSearchService).to have_received(:call).with(album)
      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("Cover art updated from itunes source")
    end

    it "redirects with alert when no cover found" do
      album = create(:album, artist: create(:artist, user: user))
      allow(CoverArtSearchService).to receive(:call).with(album).and_return(:not_found)

      post fetch_cover_album_path(album)

      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("No cover art found")
    end

    it "requires authentication" do
      album = create(:album, artist: create(:artist, user: user))
      reset!
      post fetch_cover_album_path(album)
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "PATCH /albums/:id" do
    it "saves the youtube_playlist_url" do
      album = create(:album, youtube_playlist_url: nil, artist: create(:artist, user: user))

      patch album_path(album), params: {album: {youtube_playlist_url: "https://www.youtube.com/playlist?list=PLnew"}}

      expect(response).to redirect_to(album_path(album))
      expect(album.reload.youtube_playlist_url).to eq("https://www.youtube.com/playlist?list=PLnew")
    end

    it "clears the youtube_playlist_url" do
      album = create(:album, youtube_playlist_url: "https://www.youtube.com/playlist?list=PLold", artist: create(:artist, user: user))

      patch album_path(album), params: {album: {youtube_playlist_url: ""}}

      expect(album.reload.youtube_playlist_url).to eq("")
    end

    it "requires authentication" do
      album = create(:album, artist: create(:artist, user: user))
      reset!
      patch album_path(album), params: {album: {youtube_playlist_url: "https://example.com"}}
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "POST /albums/:id/download_audio" do
    it "enqueues MediaDownloadJob for YouTube tracks without audio" do
      album = create(:album, artist: create(:artist, user: user))
      yt_track = create(:track, album: album, youtube_video_id: "abc123")
      create(:track, album: album)

      expect {
        post download_audio_album_path(album)
      }.to have_enqueued_job(MediaDownloadJob).with(yt_track.id, "https://www.youtube.com/watch?v=abc123", user_id: user.id)

      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("1 track")
    end

    it "skips YouTube tracks that already have audio attached" do
      album = create(:album, artist: create(:artist, user: user))
      yt_track = create(:track, album: album, youtube_video_id: "abc123")
      yt_track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      expect {
        post download_audio_album_path(album)
      }.not_to have_enqueued_job(MediaDownloadJob)

      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("All tracks already have audio")
    end

    it "redirects with alert when no YouTube tracks exist" do
      album = create(:album, artist: create(:artist, user: user))
      create(:track, album: album)

      post download_audio_album_path(album)

      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("No YouTube tracks to download")
    end
  end

  describe "GET /albums/:id/edit" do
    it "lets the owner open the form" do
      album = create(:album, artist: create(:artist, user: user))
      get edit_album_path(album)
      expect(response).to have_http_status(:ok)
    end

    it "renders the YouTube playlist URL field" do
      album = create(:album, artist: create(:artist, user: user))
      get edit_album_path(album)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("input[name='album[youtube_playlist_url]']")).to be_present
    end

    it "renders the form in an open modal when the modal frame asks for it" do
      album = create(:album, user: user)
      get edit_album_path(album), headers: {"Turbo-Frame" => "modal"}

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("turbo-frame#modal [data-controller='modal']")["data-modal-open-value"]).to eq("true")
      expect(doc.at_css("turbo-frame#modal dialog form[action='#{album_path(album)}'] input[name='album[title]']")).to be_present
    end

    it "offers only the owner's artists to move the album to" do
      album = create(:album, user: user)
      create(:artist, name: "Somebody Elses Artist")
      get edit_album_path(album)

      options = Nokogiri::HTML(response.body).css("select[name='album[artist_id]'] option").map(&:text)
      expect(options).to include(album.artist.name)
      expect(options).not_to include("Somebody Elses Artist")
    end

    it "offers Delete in the modal, confirmed and loaded as a full page" do
      album = create(:album, user: user)
      get edit_album_path(album), headers: {"Turbo-Frame" => "modal"}

      form = Nokogiri::HTML(response.body).at_css("dialog form[action='#{album_path(album)}']:has(input[name='_method'][value='delete'])")
      expect(form["data-turbo-frame"]).to eq("_top")
      expect(form["data-turbo-confirm"]).to include(album.title)
    end

    it "returns not found for another user's album" do
      album = create(:album)
      get edit_album_path(album)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /albums/:id (edit form)" do
    it "updates album title" do
      album = create(:album, title: "Old Title", artist: create(:artist, user: user))
      patch album_path(album), params: {album: {title: "New Title"}}

      expect(album.reload.title).to eq("New Title")
      expect(response).to redirect_to(album_path(album))
    end

    it "updates album artist" do
      old_artist = create(:artist, name: "Old Artist", user: user)
      new_artist = create(:artist, name: "New Artist", user: user)
      album = create(:album, artist: old_artist)
      track = create(:track, album: album, artist: old_artist)

      patch album_path(album), params: {album: {artist_id: new_artist.id}}

      album.reload
      expect(album.artist).to eq(new_artist)
      expect(track.reload.artist).to eq(new_artist)
    end

    it "renders edit on validation error" do
      existing = create(:album, title: "Taken", artist: create(:artist, name: "Same", user: user))
      album = create(:album, title: "Other", artist: existing.artist)

      patch album_path(album), params: {album: {title: "Taken"}}

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refreshes the page under the modal after a save from it" do
      album = create(:album, title: "Old Title", user: user)
      patch album_path(album), params: {album: {title: "New Title"}},
        headers: {"Turbo-Frame" => "modal", "X-Turbo-Request-Id" => "req-1"}

      stream = Nokogiri::HTML(response.body).at_css("turbo-stream[action='refresh']")
      expect(stream).to be_present
      expect(stream["request-id"]).to be_nil
      expect(flash[:notice]).to eq("Album updated.")
    end

    it "shows the errors inside the modal when the save fails" do
      existing = create(:album, title: "Taken", user: user)
      album = create(:album, title: "Other", artist: existing.artist)

      patch album_path(album), params: {album: {title: "Taken"}}, headers: {"Turbo-Frame" => "modal"}

      expect(response).to have_http_status(:unprocessable_content)
      expect(Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog").text).to include("Title has already been taken")
    end

    it "refuses to move the album to another user's artist" do
      artist = create(:artist, user: user)
      album = create(:album, artist: artist)
      foreign_artist = create(:artist)

      patch album_path(album), params: {album: {artist_id: foreign_artist.id}}

      expect(response).to have_http_status(:unprocessable_content)
      expect(album.reload.artist).to eq(artist)
    end
  end

  describe "DELETE /albums/:id" do
    it "deletes the album and its tracks" do
      album = create(:album, artist: create(:artist, user: user))
      create(:track, album: album)

      expect {
        delete album_path(album)
      }.to change(Album, :count).by(-1).and change(Track, :count).by(-1)

      expect(response).to redirect_to(artist_path(album.artist))
    end

    it "returns to the page the delete came from" do
      album = create(:album, user: user)
      delete album_path(album), headers: {"Referer" => albums_url(q: "al")}
      expect(response).to redirect_to(albums_url(q: "al"))
    end

    it "goes to the artist when deleted from its own page" do
      album = create(:album, user: user)
      delete album_path(album), headers: {"Referer" => album_url(album)}
      expect(response).to redirect_to(artist_path(album.artist))
    end

    it "keeps another user's album" do
      album = create(:album)
      delete album_path(album)
      expect(response).to have_http_status(:not_found)
      expect(Album.exists?(album.id)).to be true
    end
  end

  describe "POST /albums/:id/merge" do
    it "merges source album into target" do
      target = create(:album, title: "Target", artist: create(:artist, user: user))
      source = create(:album, title: "Source", artist: create(:artist, user: user))
      track = create(:track, album: source, artist: source.artist)

      post merge_album_path(target), params: {source_album_id: source.id}

      expect(track.reload.album).to eq(target)
      expect(Album.exists?(source.id)).to be false
      expect(response).to redirect_to(album_path(target))
    end

    it "rejects self-merge" do
      album = create(:album, artist: create(:artist, user: user))
      post merge_album_path(album), params: {source_album_id: album.id}

      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("Cannot merge an album into itself")
    end

    it "keeps another user's album out of the merge" do
      album = create(:album, artist: create(:artist, user: user))
      source = create(:album)
      post merge_album_path(album), params: {source_album_id: source.id}
      expect(response).to have_http_status(:not_found)
      expect(Album.exists?(source.id)).to be true
    end
  end

  describe "POST /albums/:id/create_playlist" do
    it "creates a playlist named after the album with all tracks in disc/track order" do
      album = create(:album, title: "Great Album", artist: create(:artist, user: user))
      track3 = create(:track, album: album, disc_number: 2, track_number: 1, title: "Disc 2 Track 1")
      track1 = create(:track, album: album, disc_number: 1, track_number: 1, title: "Disc 1 Track 1")
      track2 = create(:track, album: album, disc_number: 1, track_number: 2, title: "Disc 1 Track 2")

      expect {
        post create_playlist_album_path(album)
      }.to change(Playlist, :count).by(1)

      playlist = user.playlists.last
      expect(playlist.name).to eq("Great Album")
      expect(playlist.playlist_tracks.order(:position).map(&:track)).to eq([track1, track2, track3])
      expect(response).to redirect_to(playlist_path(playlist))
    end

    it "requires authentication" do
      album = create(:album, artist: create(:artist, user: user))
      reset!
      post create_playlist_album_path(album)
      expect(response).to redirect_to(new_session_path)
    end
  end
end
