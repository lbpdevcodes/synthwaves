require "rails_helper"

RSpec.describe "MCP agent gateway tools", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:auth) do
    {"Authorization" => "Basic #{Base64.strict_encode64("#{api_key.client_id}:test_secret_key_123")}"}
  end

  def call_tool(name, arguments = {})
    post "/mcp",
      params: JSON.generate({
        "jsonrpc" => "2.0", "id" => 1, "method" => "tools/call",
        "params" => {"name" => name, "arguments" => arguments}
      }),
      headers: {"CONTENT_TYPE" => "application/json"}.merge(auth)
    response.parsed_body
  end

  def tool_payload(body)
    JSON.parse(body.dig("result", "content", 0, "text"))
  end

  def tool_error?(body)
    body.dig("result", "isError") == true
  end

  def tool_error_message(body)
    body.dig("result", "content", 0, "text")
  end

  describe "search" do
    it "finds the user's own artists, albums, and tracks by title fragment" do
      artist = create(:artist, user: user, name: "Perturbator")
      album = create(:album, user: user, artist: artist, title: "Perturbator Deluxe")
      create(:track, user: user, artist: artist, album: album, title: "Perturbator Theme")
      create(:track, user: user, artist: artist, album: album, title: "Unrelated")

      payload = tool_payload(call_tool("search", {"query" => "Perturbator"}))

      expect(payload["artists"].map { |a| a["name"] }).to include("Perturbator")
      expect(payload["albums"].map { |a| a["title"] }).to include("Perturbator Deluxe")
      expect(payload["tracks"].map { |t| t["title"] }).to include("Perturbator Theme")
      expect(payload["tracks"].map { |t| t["title"] }).not_to include("Unrelated")
    end

    it "does not return another user's records" do
      create(:artist, user: other_user, name: "Perturbator")

      payload = tool_payload(call_tool("search", {"query" => "Perturbator"}))

      expect(payload["artists"]).to be_empty
    end

    it "returns an error result when query is missing" do
      body = call_tool("search", {})

      expect(tool_error?(body)).to be true
    end
  end

  describe "list_artists" do
    it "lists only the user's own artists" do
      create(:artist, user: user, name: "Perturbator")
      create(:artist, user: other_user, name: "Carpenter Brut")

      payload = tool_payload(call_tool("list_artists"))

      expect(payload["artists"].map { |a| a["name"] }).to contain_exactly("Perturbator")
    end

    it "narrows the list with the q filter" do
      create(:artist, user: user, name: "Perturbator")
      create(:artist, user: user, name: "Carpenter Brut")

      payload = tool_payload(call_tool("list_artists", {"q" => "pert"}))

      expect(payload["artists"].map { |a| a["name"] }).to contain_exactly("Perturbator")
    end
  end

  describe "get_artist" do
    it "returns the artist with their albums" do
      artist = create(:artist, user: user, name: "Perturbator")
      create(:album, user: user, artist: artist, title: "Dangerous Days")

      payload = tool_payload(call_tool("get_artist", {"artist_id" => artist.id}))

      expect(payload["name"]).to eq("Perturbator")
      expect(payload["albums"].map { |a| a["title"] }).to eq(["Dangerous Days"])
    end

    it "returns an error result for another user's artist" do
      artist = create(:artist, user: other_user)

      body = call_tool("get_artist", {"artist_id" => artist.id})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to eq("Record not found")
    end
  end

  describe "list_albums" do
    it "filters albums by artist_id" do
      artist = create(:artist, user: user)
      other_artist = create(:artist, user: user)
      create(:album, user: user, artist: artist, title: "Dangerous Days")
      create(:album, user: user, artist: other_artist, title: "Leather Teeth")

      payload = tool_payload(call_tool("list_albums", {"artist_id" => artist.id}))

      expect(payload["albums"].map { |a| a["title"] }).to contain_exactly("Dangerous Days")
    end
  end

  describe "get_album" do
    it "returns the album with tracks in disc/track order and total duration" do
      album = create(:album, user: user)
      create(:track, user: user, album: album, artist: album.artist, title: "Second", track_number: 2, duration: 60)
      create(:track, user: user, album: album, artist: album.artist, title: "First", track_number: 1, duration: 120)

      payload = tool_payload(call_tool("get_album", {"album_id" => album.id}))

      expect(payload["tracks"].map { |t| t["title"] }).to eq(%w[First Second])
      expect(payload["total_duration"]).to eq(180)
    end

    it "returns an error result for another user's album" do
      album = create(:album, user: other_user)

      body = call_tool("get_album", {"album_id" => album.id})

      expect(tool_error?(body)).to be true
    end
  end

  describe "list_tracks" do
    it "filters tracks by album_id" do
      album = create(:album, user: user)
      other_album = create(:album, user: user)
      create(:track, user: user, album: album, artist: album.artist, title: "On Album")
      create(:track, user: user, album: other_album, artist: other_album.artist, title: "Elsewhere")

      payload = tool_payload(call_tool("list_tracks", {"album_id" => album.id}))

      expect(payload["tracks"].map { |t| t["title"] }).to contain_exactly("On Album")
    end

    it "finds tracks by title with the q filter" do
      create(:track, user: user, title: "Midnight Drive")
      create(:track, user: user, title: "Sunset Boulevard")

      payload = tool_payload(call_tool("list_tracks", {"q" => "Midnight"}))

      expect(payload["tracks"].map { |t| t["title"] }).to contain_exactly("Midnight Drive")
    end
  end

  describe "get_track" do
    it "returns the full track payload" do
      track = create(:track, user: user, title: "Midnight Drive")

      payload = tool_payload(call_tool("get_track", {"track_id" => track.id}))

      expect(payload["title"]).to eq("Midnight Drive")
      expect(payload["has_audio"]).to be true
    end

    it "returns an error result for another user's track" do
      track = create(:track, user: other_user)

      body = call_tool("get_track", {"track_id" => track.id})

      expect(tool_error?(body)).to be true
    end
  end

  describe "list_playlists" do
    it "lists the user's playlists with track counts" do
      playlist = create(:playlist, user: user, name: "Synthwave Classics")
      playlist.add_track(create(:track, user: user))

      payload = tool_payload(call_tool("list_playlists"))

      entry = payload["playlists"].find { |p| p["name"] == "Synthwave Classics" }
      expect(entry["tracks_count"]).to eq(1)
    end
  end

  describe "get_playlist" do
    it "returns tracks in position order with playlist_track_id values" do
      playlist = create(:playlist, user: user)
      first = create(:track, user: user, title: "First")
      second = create(:track, user: user, title: "Second")
      playlist.add_tracks([first, second])

      payload = tool_payload(call_tool("get_playlist", {"playlist_id" => playlist.id}))

      expect(payload["tracks"].map { |t| t.dig("track", "title") }).to eq(%w[First Second])
      expect(payload["tracks"].map { |t| t["position"] }).to eq([1, 2])
      expect(payload["tracks"].first["playlist_track_id"]).to be_present
      expect(payload["total_duration"]).to eq(360)
    end

    it "returns an error result for another user's playlist" do
      playlist = create(:playlist, user: other_user)

      body = call_tool("get_playlist", {"playlist_id" => playlist.id})

      expect(tool_error?(body)).to be true
    end
  end

  describe "list_favorites" do
    it "filters favorites by type" do
      track = create(:track, user: user)
      artist = create(:artist, user: user)
      user.favorites.create!(favorable: track)
      user.favorites.create!(favorable: artist)

      payload = tool_payload(call_tool("list_favorites", {"type" => "Track"}))

      expect(payload["favorites"].map { |f| f["favorable_type"] }).to eq(["Track"])
      expect(payload["count"]).to eq(1)
    end
  end

  describe "create_playlist" do
    it "creates a playlist with the given name" do
      payload = tool_payload(call_tool("create_playlist", {"name" => "Night Drive"}))

      expect(payload["name"]).to eq("Night Drive")
      expect(user.playlists.find_by(name: "Night Drive")).to be_present
    end

    it "adds track_ids in the given order" do
      first = create(:track, user: user)
      second = create(:track, user: user)

      payload = tool_payload(call_tool("create_playlist", {"name" => "Mix", "track_ids" => [second.id, first.id]}))

      playlist = user.playlists.find(payload["id"])
      expect(playlist.tracks.order("playlist_tracks.position")).to eq([second, first])
    end

    it "returns an error result for a blank name" do
      body = call_tool("create_playlist", {"name" => ""})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("Name")
    end
  end

  describe "update_playlist" do
    it "renames the playlist" do
      playlist = create(:playlist, user: user, name: "Old Name")

      payload = tool_payload(call_tool("update_playlist", {"playlist_id" => playlist.id, "name" => "New Name"}))

      expect(payload["name"]).to eq("New Name")
      expect(playlist.reload.name).to eq("New Name")
    end

    it "returns an error result for a blank name" do
      playlist = create(:playlist, user: user)

      body = call_tool("update_playlist", {"playlist_id" => playlist.id, "name" => ""})

      expect(tool_error?(body)).to be true
      expect(playlist.reload.name).to be_present
    end
  end

  describe "delete_playlist" do
    it "deletes the playlist but not its tracks" do
      playlist = create(:playlist, user: user, name: "Doomed")
      playlist.add_track(create(:track, user: user))

      payload = tool_payload(call_tool("delete_playlist", {"playlist_id" => playlist.id}))

      expect(payload["deleted"]).to be true
      expect(payload["name"]).to eq("Doomed")
      expect(user.playlists.find_by(id: playlist.id)).to be_nil
      expect(user.tracks.count).to eq(1)
    end

    it "returns an error result for another user's playlist" do
      playlist = create(:playlist, user: other_user)

      body = call_tool("delete_playlist", {"playlist_id" => playlist.id})

      expect(tool_error?(body)).to be true
      expect(Playlist.exists?(playlist.id)).to be true
    end
  end

  describe "add_tracks_to_playlist" do
    it "adds tracks in order and skips duplicates" do
      playlist = create(:playlist, user: user)
      first = create(:track, user: user)
      second = create(:track, user: user)
      playlist.add_track(first)

      payload = tool_payload(call_tool("add_tracks_to_playlist",
        {"playlist_id" => playlist.id, "track_ids" => [second.id, first.id]}))

      expect(payload["added"]).to eq(1)
      expect(payload["tracks_count"]).to eq(2)
      expect(playlist.tracks.order("playlist_tracks.position")).to eq([first, second])
    end

    it "adds an album's tracks in disc/track order" do
      playlist = create(:playlist, user: user)
      album = create(:album, user: user)
      second = create(:track, user: user, album: album, artist: album.artist, track_number: 2)
      first = create(:track, user: user, album: album, artist: album.artist, track_number: 1)

      payload = tool_payload(call_tool("add_tracks_to_playlist",
        {"playlist_id" => playlist.id, "album_id" => album.id}))

      expect(payload["added"]).to eq(2)
      expect(playlist.tracks.order("playlist_tracks.position")).to eq([first, second])
    end

    it "returns an error result when both track_ids and album_id are given" do
      playlist = create(:playlist, user: user)
      track = create(:track, user: user)

      body = call_tool("add_tracks_to_playlist",
        {"playlist_id" => playlist.id, "track_ids" => [track.id], "album_id" => 1})

      expect(tool_error?(body)).to be true
    end

    it "returns an error result for another user's playlist" do
      playlist = create(:playlist, user: other_user)
      track = create(:track, user: user)

      body = call_tool("add_tracks_to_playlist", {"playlist_id" => playlist.id, "track_ids" => [track.id]})

      expect(tool_error?(body)).to be true
    end
  end

  describe "remove_playlist_track" do
    it "removes the entry from the playlist" do
      playlist = create(:playlist, user: user)
      playlist.add_track(create(:track, user: user))
      playlist_track = playlist.playlist_tracks.first

      payload = tool_payload(call_tool("remove_playlist_track",
        {"playlist_id" => playlist.id, "playlist_track_id" => playlist_track.id}))

      expect(payload["removed"]).to be true
      expect(payload["tracks_count"]).to eq(0)
    end

    it "returns an error result for an entry from a different playlist" do
      playlist = create(:playlist, user: user)
      other_playlist = create(:playlist, user: user)
      other_playlist.add_track(create(:track, user: user))
      foreign_entry = other_playlist.playlist_tracks.first

      body = call_tool("remove_playlist_track",
        {"playlist_id" => playlist.id, "playlist_track_id" => foreign_entry.id})

      expect(tool_error?(body)).to be true
      expect(PlaylistTrack.exists?(foreign_entry.id)).to be true
    end
  end

  describe "reorder_playlist" do
    it "persists the new track order" do
      playlist = create(:playlist, user: user)
      tracks = create_list(:track, 3, user: user)
      playlist.add_tracks(tracks)
      ids = playlist.playlist_tracks.order(:position).pluck(:id)

      payload = tool_payload(call_tool("reorder_playlist",
        {"playlist_id" => playlist.id, "playlist_track_ids" => ids.reverse}))

      expect(payload["reordered"]).to eq(3)
      expect(playlist.playlist_tracks.order(:position).pluck(:id)).to eq(ids.reverse)
    end

    it "returns an error result for an empty id array" do
      playlist = create(:playlist, user: user)

      body = call_tool("reorder_playlist", {"playlist_id" => playlist.id, "playlist_track_ids" => []})

      expect(tool_error?(body)).to be true
    end
  end

  describe "create_playlist_from_album" do
    it "creates a playlist named after the album with all its tracks" do
      album = create(:album, user: user, title: "Dangerous Days")
      create_list(:track, 2, user: user, album: album, artist: album.artist)

      payload = tool_payload(call_tool("create_playlist_from_album", {"album_id" => album.id}))

      expect(payload["name"]).to eq("Dangerous Days")
      expect(payload["added"]).to eq(2)
      playlist = user.playlists.find(payload["id"])
      expect(playlist.tracks.count).to eq(2)
    end
  end

  describe "favorite" do
    it "creates a favorite for the record" do
      track = create(:track, user: user)

      payload = tool_payload(call_tool("favorite", {"favorable_type" => "Track", "favorable_id" => track.id}))

      expect(payload["favorable_type"]).to eq("Track")
      expect(payload["favorable_id"]).to eq(track.id)
      expect(user.favorites.count).to eq(1)
    end

    it "is idempotent for an already-favorited record" do
      track = create(:track, user: user)
      user.favorites.create!(favorable: track)

      payload = tool_payload(call_tool("favorite", {"favorable_type" => "Track", "favorable_id" => track.id}))

      expect(payload["favorable_id"]).to eq(track.id)
      expect(user.favorites.count).to eq(1)
    end

    it "returns an error result for another user's record" do
      track = create(:track, user: other_user)

      body = call_tool("favorite", {"favorable_type" => "Track", "favorable_id" => track.id})

      expect(tool_error?(body)).to be true
    end

    it "returns an error result for an unsupported type" do
      body = call_tool("favorite", {"favorable_type" => "Video", "favorable_id" => 1})

      expect(tool_error?(body)).to be true
    end
  end

  describe "unfavorite" do
    it "removes an existing favorite" do
      track = create(:track, user: user)
      user.favorites.create!(favorable: track)

      payload = tool_payload(call_tool("unfavorite", {"favorable_type" => "Track", "favorable_id" => track.id}))

      expect(payload["removed"]).to be true
      expect(user.favorites.count).to eq(0)
    end

    it "reports removed false when the record was not favorited" do
      track = create(:track, user: user)

      payload = tool_payload(call_tool("unfavorite", {"favorable_type" => "Track", "favorable_id" => track.id}))

      expect(payload["removed"]).to be false
    end
  end

  describe "upload_track" do
    let(:audio_base64) { Base64.strict_encode64(File.binread(Rails.root.join("spec/fixtures/files/test.mp3"))) }

    it "creates a track with audio attached" do
      payload = tool_payload(call_tool("upload_track",
        {"filename" => "banger.mp3", "audio_base64" => audio_base64}))

      expect(payload["created"]).to be true
      expect(payload["has_audio"]).to be true
      track = user.tracks.find(payload["id"])
      expect(track.audio_file).to be_attached
    end

    it "lets explicit metadata override embedded tags" do
      payload = tool_payload(call_tool("upload_track",
        {"filename" => "banger.mp3", "audio_base64" => audio_base64, "title" => "Explicit Title"}))

      expect(payload["title"]).to eq("Explicit Title")
    end

    it "reuses an existing artist rather than duplicating it" do
      artist = create(:artist, user: user, name: "Existing Artist")

      payload = nil
      expect {
        payload = tool_payload(call_tool("upload_track",
          {"filename" => "banger.mp3", "audio_base64" => audio_base64, "artist_name" => "Existing Artist"}))
      }.not_to change(user.artists, :count)
      expect(payload["created"]).to be true
      expect(payload.dig("artist", "id")).to eq(artist.id)
    end

    it "returns an error result for invalid base64" do
      body = call_tool("upload_track", {"filename" => "banger.mp3", "audio_base64" => "not base64!!!"})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("base64")
    end

    it "returns an error result when the filename has no extension" do
      body = call_tool("upload_track", {"filename" => "banger", "audio_base64" => audio_base64})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("extension")
    end
  end

  describe "import_youtube_playlist" do
    it "imports the playlist metadata and reports missing audio" do
      album = create(:album, user: user, title: "Imported")
      create_list(:track, 2, user: user, album: album, artist: album.artist, youtube_video_id: "abc123")
      allow(YoutubeAlbumImportService).to receive(:call).and_return(album)

      payload = tool_payload(call_tool("import_youtube_playlist",
        {"url" => "https://youtube.com/playlist?list=PL123"}))

      expect(payload["album_id"]).to eq(album.id)
      expect(payload["title"]).to eq("Imported")
      expect(payload["track_count"]).to eq(2)
      expect(payload["tracks_missing_audio"]).to eq(2)
    end

    it "returns an error result when no videos are found" do
      allow(YoutubeAlbumImportService).to receive(:call).and_return(nil)

      body = call_tool("import_youtube_playlist", {"url" => "https://youtube.com/playlist?list=empty"})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("No videos found")
    end

    it "returns an error result when the import service fails" do
      allow(YoutubeAlbumImportService).to receive(:call)
        .and_raise(YoutubeAPIService::Error, "quota exceeded")

      body = call_tool("import_youtube_playlist", {"url" => "https://youtube.com/playlist?list=PL123"})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("quota exceeded")
    end
  end
end
