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

  describe "response format" do
    it "returns compact JSON without pretty-printing" do
      create(:playlist, user: user)

      body = call_tool("list_playlists")
      text = body.dig("result", "content", 0, "text")

      expect(text).to eq(JSON.generate(JSON.parse(text)))
    end
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

  describe "match_tracks" do
    it "resolves a mixed batch of queries in request order" do
      artist = create(:artist, user: user, name: "New Order")
      album = create(:album, user: user, artist: artist, title: "PCL")
      exact = create(:track, user: user, artist: artist, album: album, title: "Blue Monday")
      partial = create(:track, user: user, artist: artist, album: album, title: "Age of Consent")

      payload = tool_payload(call_tool("match_tracks",
        {"queries" => ["New Order - Blue Monday", "age of cons", "Everything's Gone Green"]}))

      expect(payload["results"].map { |r| r["query"] }).to eq(
        ["New Order - Blue Monday", "age of cons", "Everything's Gone Green"]
      )
      first, second, third = payload["results"]
      expect(first["matched"]).to be true
      expect(first["confidence"]).to eq("exact")
      expect(first["track"]).to eq({"id" => exact.id, "title" => "Blue Monday", "artist" => "New Order"})
      expect(second["matched"]).to be true
      expect(second["confidence"]).to eq("partial")
      expect(second["track"]["id"]).to eq(partial.id)
      expect(third["matched"]).to be false
      expect(third["track"]).to be_nil
      expect(third["confidence"]).to be_nil
    end

    it "does not match tracks outside the user's library" do
      foreign_artist = create(:artist, user: other_user, name: "New Order")
      foreign_album = create(:album, user: other_user, artist: foreign_artist, title: "PCL")
      create(:track, user: other_user, artist: foreign_artist, album: foreign_album, title: "Blue Monday")

      payload = tool_payload(call_tool("match_tracks", {"queries" => ["Blue Monday"]}))

      expect(payload["results"].first["matched"]).to be false
    end

    it "returns an error result for more than 200 queries" do
      body = call_tool("match_tracks", {"queries" => Array.new(201, "x")})

      expect(tool_error?(body)).to be true
    end

    it "returns an error result for an empty query string" do
      body = call_tool("match_tracks", {"queries" => [""]})

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

    it "returns all tracks without pagination metadata by default" do
      playlist = create(:playlist, user: user)
      playlist.add_tracks(create_list(:track, 3, user: user))

      payload = tool_payload(call_tool("get_playlist", {"playlist_id" => playlist.id}))

      expect(payload["tracks"].size).to eq(3)
      expect(payload).not_to have_key("pagination")
    end

    it "returns flat rows when compact is true" do
      playlist = create(:playlist, user: user)
      artist = create(:artist, user: user, name: "Perturbator")
      album = create(:album, user: user, artist: artist)
      track = create(:track, user: user, artist: artist, album: album, title: "Sentient", duration: 372)
      playlist.add_track(track)
      entry = playlist.playlist_tracks.first

      payload = tool_payload(call_tool("get_playlist", {"playlist_id" => playlist.id, "compact" => true}))

      expect(payload["tracks"]).to eq([{
        "position" => 1,
        "playlist_track_id" => entry.id,
        "track_id" => track.id,
        "title" => "Sentient",
        "artist" => "Perturbator",
        "duration" => 372
      }])
    end

    it "pages tracks with pagination metadata" do
      playlist = create(:playlist, user: user)
      tracks = create_list(:track, 5, user: user)
      playlist.add_tracks(tracks)

      payload = tool_payload(call_tool("get_playlist",
        {"playlist_id" => playlist.id, "page" => 2, "per_page" => 2}))

      expect(payload["tracks"].map { |t| t.dig("track", "title") }).to eq(
        [tracks[2].title, tracks[3].title]
      )
      expect(payload["pagination"]).to eq(
        {"page" => 2, "per_page" => 2, "total_pages" => 3, "total_count" => 5}
      )
    end

    it "treats per_page without page as page 1" do
      playlist = create(:playlist, user: user)
      tracks = create_list(:track, 3, user: user)
      playlist.add_tracks(tracks)

      payload = tool_payload(call_tool("get_playlist",
        {"playlist_id" => playlist.id, "per_page" => 2}))

      expect(payload["tracks"].map { |t| t.dig("track", "title") }).to eq(
        [tracks[0].title, tracks[1].title]
      )
      expect(payload["pagination"]["page"]).to eq(1)
    end

    it "returns empty tracks with metadata for a page beyond the end" do
      playlist = create(:playlist, user: user)
      playlist.add_tracks(create_list(:track, 2, user: user))

      payload = tool_payload(call_tool("get_playlist",
        {"playlist_id" => playlist.id, "page" => 5, "per_page" => 50}))

      expect(payload["tracks"]).to be_empty
      expect(payload["pagination"]).to eq(
        {"page" => 5, "per_page" => 50, "total_pages" => 1, "total_count" => 2}
      )
    end

    it "combines compact rows with pagination" do
      playlist = create(:playlist, user: user)
      playlist.add_tracks(create_list(:track, 3, user: user))

      payload = tool_payload(call_tool("get_playlist",
        {"playlist_id" => playlist.id, "compact" => true, "page" => 2, "per_page" => 2}))

      expect(payload["tracks"].size).to eq(1)
      expect(payload["tracks"].first.keys).to contain_exactly(
        "position", "playlist_track_id", "track_id", "title", "artist", "duration"
      )
      expect(payload["pagination"]["total_count"]).to eq(3)
    end

    it "keeps total_duration as the whole-playlist total when paged" do
      playlist = create(:playlist, user: user)
      playlist.add_tracks(create_list(:track, 5, user: user, duration: 60))

      payload = tool_payload(call_tool("get_playlist",
        {"playlist_id" => playlist.id, "page" => 1, "per_page" => 2}))

      expect(payload["total_duration"]).to eq(300)
    end

    it "returns an error result when per_page exceeds 500" do
      playlist = create(:playlist, user: user)

      body = call_tool("get_playlist", {"playlist_id" => playlist.id, "per_page" => 501})

      expect(tool_error?(body)).to be true
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

    it "rejects more than 500 track_ids without creating the playlist" do
      track = create(:track, user: user)

      body = call_tool("create_playlist",
        {"name" => "Too Big", "track_ids" => [track.id] + ((track.id + 1)..(track.id + 500)).to_a})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("500")
      expect(user.playlists.find_by(name: "Too Big")).to be_nil
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

    it "rejects more than 500 track_ids without changing the playlist" do
      playlist = create(:playlist, user: user)
      track = create(:track, user: user)

      body = call_tool("add_tracks_to_playlist",
        {"playlist_id" => playlist.id, "track_ids" => [track.id] + ((track.id + 1)..(track.id + 500)).to_a})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("500")
      expect(playlist.reload.playlist_tracks_count).to eq(0)
    end

    it "accepts exactly 500 track_ids" do
      playlist = create(:playlist, user: user)
      track = create(:track, user: user)

      payload = tool_payload(call_tool("add_tracks_to_playlist",
        {"playlist_id" => playlist.id, "track_ids" => [track.id] + ((track.id + 1)..(track.id + 499)).to_a}))

      expect(payload["added"]).to eq(1)
    end

    it "accumulates across chunked calls and skips tracks already in the playlist" do
      playlist = create(:playlist, user: user)
      tracks = create_list(:track, 4, user: user)

      call_tool("add_tracks_to_playlist",
        {"playlist_id" => playlist.id, "track_ids" => tracks.first(3).map(&:id)})
      payload = tool_payload(call_tool("add_tracks_to_playlist",
        {"playlist_id" => playlist.id, "track_ids" => tracks.last(2).map(&:id)}))

      expect(payload["added"]).to eq(1)
      expect(payload["tracks_count"]).to eq(4)
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

  describe "remove_playlist_tracks" do
    it "removes many entries by playlist_track_ids" do
      playlist = create(:playlist, user: user)
      tracks = create_list(:track, 3, user: user)
      playlist.add_tracks(tracks)
      entries = playlist.playlist_tracks.order(:position).to_a
      survivor = entries.last

      payload = tool_payload(call_tool("remove_playlist_tracks",
        {"playlist_id" => playlist.id, "playlist_track_ids" => entries.first(2).map(&:id)}))

      expect(payload["removed"]).to eq(2)
      expect(payload["tracks_count"]).to eq(1)
      expect(playlist.playlist_tracks.order(:position).pluck(:id)).to eq([survivor.id])
    end

    it "removes every entry with the given track_ids, including duplicates" do
      playlist = create(:playlist, user: user)
      repeated = create(:track, user: user)
      keeper = create(:track, user: user)
      playlist.playlist_tracks.create!(track: repeated, position: 1)
      playlist.playlist_tracks.create!(track: keeper, position: 2)
      playlist.playlist_tracks.create!(track: repeated, position: 3)

      payload = tool_payload(call_tool("remove_playlist_tracks",
        {"playlist_id" => playlist.id, "track_ids" => [repeated.id]}))

      expect(payload["removed"]).to eq(2)
      expect(playlist.tracks.order("playlist_tracks.position")).to eq([keeper])
    end

    it "updates the counter cache after a bulk delete" do
      playlist = create(:playlist, user: user)
      tracks = create_list(:track, 3, user: user)
      playlist.add_tracks(tracks)

      call_tool("remove_playlist_tracks",
        {"playlist_id" => playlist.id, "track_ids" => tracks.first(2).map(&:id)})

      expect(playlist.reload.playlist_tracks_count).to eq(1)
    end

    it "returns an error when both id arrays are given" do
      playlist = create(:playlist, user: user)

      body = call_tool("remove_playlist_tracks",
        {"playlist_id" => playlist.id, "playlist_track_ids" => [1], "track_ids" => [2]})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("exactly one")
    end

    it "returns an error when neither id array is given" do
      playlist = create(:playlist, user: user)

      body = call_tool("remove_playlist_tracks", {"playlist_id" => playlist.id})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("exactly one")
    end

    it "ignores unknown ids and counts only actual removals" do
      playlist = create(:playlist, user: user)
      playlist.add_track(create(:track, user: user))
      entry = playlist.playlist_tracks.first

      payload = tool_payload(call_tool("remove_playlist_tracks",
        {"playlist_id" => playlist.id, "playlist_track_ids" => [entry.id, entry.id + 1000]}))

      expect(payload["removed"]).to eq(1)
      expect(payload["tracks_count"]).to eq(0)
    end

    it "does not touch entries from a different playlist" do
      playlist = create(:playlist, user: user)
      playlist.add_track(create(:track, user: user))
      other_playlist = create(:playlist, user: user)
      other_playlist.add_track(create(:track, user: user))
      foreign_entry = other_playlist.playlist_tracks.first

      payload = tool_payload(call_tool("remove_playlist_tracks",
        {"playlist_id" => playlist.id, "playlist_track_ids" => [foreign_entry.id]}))

      expect(payload["removed"]).to eq(0)
      expect(PlaylistTrack.exists?(foreign_entry.id)).to be true
    end

    it "returns an error result for another user's playlist" do
      playlist = create(:playlist, user: other_user)

      body = call_tool("remove_playlist_tracks",
        {"playlist_id" => playlist.id, "track_ids" => [1]})

      expect(tool_error?(body)).to be true
    end

    it "is idempotent for a repeated call" do
      playlist = create(:playlist, user: user)
      track = create(:track, user: user)
      playlist.add_track(track)

      call_tool("remove_playlist_tracks", {"playlist_id" => playlist.id, "track_ids" => [track.id]})
      payload = tool_payload(call_tool("remove_playlist_tracks",
        {"playlist_id" => playlist.id, "track_ids" => [track.id]}))

      expect(payload["removed"]).to eq(0)
      expect(payload["tracks_count"]).to eq(0)
    end

    it "rejects more than 500 track_ids without removing anything" do
      playlist = create(:playlist, user: user)
      track = create(:track, user: user)
      playlist.add_track(track)

      body = call_tool("remove_playlist_tracks",
        {"playlist_id" => playlist.id, "track_ids" => [track.id] + ((track.id + 1)..(track.id + 500)).to_a})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("500")
      expect(playlist.reload.playlist_tracks_count).to eq(1)
    end

    it "rejects more than 500 playlist_track_ids without removing anything" do
      playlist = create(:playlist, user: user)
      playlist.add_track(create(:track, user: user))
      entry = playlist.playlist_tracks.first

      body = call_tool("remove_playlist_tracks",
        {"playlist_id" => playlist.id,
         "playlist_track_ids" => [entry.id] + ((entry.id + 1)..(entry.id + 500)).to_a})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("500")
      expect(playlist.reload.playlist_tracks_count).to eq(1)
    end

    it "accepts exactly 500 track_ids" do
      playlist = create(:playlist, user: user)
      track = create(:track, user: user)
      playlist.add_track(track)

      payload = tool_payload(call_tool("remove_playlist_tracks",
        {"playlist_id" => playlist.id, "track_ids" => [track.id] + ((track.id + 1)..(track.id + 499)).to_a}))

      expect(payload["removed"]).to eq(1)
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

  describe "update_tracks" do
    # The YouTube-import shape this tool exists to repair: the channel owner
    # credited as the artist, and the album named after the channel's upload.
    # One channel artist owning one channel album, however many tracks hang off
    # it -- Artist and Album both validate name/title uniqueness.
    def channel_track(owner, title: "Shakira - Inevitable (Official HD Video)")
      artist = owner.artists.find_or_create_by!(name: "Diego Pradilla")
      album = owner.albums.find_or_create_by!(artist: artist, title: "90s Latin Music")
      create(:track, user: owner, artist: artist, album: album, title: title)
    end

    it "applies several edits in one call" do
      first = channel_track(user)
      second = channel_track(user, title: "Selena - Amor Prohibido")

      payload = tool_payload(call_tool("update_tracks", {"edits" => [
        {"track_id" => first.id, "artist" => "Shakira", "title" => "Inevitable", "year" => 1998},
        {"track_id" => second.id, "artist" => "Selena", "title" => "Amor Prohibido"}
      ]}))

      expect(payload["updated"]).to eq(2)
      expect(first.reload.artist.name).to eq("Shakira")
      expect(first.release_year).to eq(1998)
      expect(second.reload.title).to eq("Amor Prohibido")
    end

    it "moves the album under the new artist" do
      track = channel_track(user)

      call_tool("update_tracks", {"edits" => [
        {"track_id" => track.id, "artist" => "Santana", "album" => "Supernatural"}
      ]})

      expect(track.reload.album.title).to eq("Supernatural")
      expect(track.album.artist).to eq(track.artist)
    end

    it "applies the good rows even when one row fails" do
      good = channel_track(user)
      bad = channel_track(user, title: "Keeps its title")

      payload = tool_payload(call_tool("update_tracks", {"edits" => [
        {"track_id" => good.id, "artist" => "Shakira", "title" => "Inevitable"},
        {"track_id" => bad.id, "title" => ""}
      ]}))

      expect(payload["updated"]).to eq(1)
      expect(payload["failed"]).to eq(1)
      expect(good.reload.title).to eq("Inevitable")
      expect(bad.reload.title).to eq("Keeps its title")
    end

    it "reports another user's track as failed and leaves it untouched" do
      foreign = channel_track(other_user)

      payload = tool_payload(call_tool("update_tracks", {"edits" => [
        {"track_id" => foreign.id, "artist" => "Shakira"}
      ]}))

      expect(payload["failed"]).to eq(1)
      expect(payload["results"].first["updated"]).to be false
      expect(foreign.reload.artist.name).to eq("Diego Pradilla")
    end

    it "rejects more than 500 edits without changing anything" do
      track = channel_track(user)
      edits = Array.new(501) { {"track_id" => track.id, "artist" => "Shakira"} }

      body = call_tool("update_tracks", {"edits" => edits})

      expect(tool_error?(body)).to be true
      expect(tool_error_message(body)).to include("500")
      expect(track.reload.artist.name).to eq("Diego Pradilla")
    end

    it "keeps the search index in step with a renamed track" do
      track = channel_track(user)

      call_tool("update_tracks", {"edits" => [
        {"track_id" => track.id, "artist" => "Shakira", "title" => "Inevitable"}
      ]})
      payload = tool_payload(call_tool("search", {"query" => "Inevitable"}))

      expect(payload["tracks"].map { |t| t["id"] }).to include(track.id)
    end
  end
end
