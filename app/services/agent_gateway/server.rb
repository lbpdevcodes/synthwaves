module AgentGateway
  # Builds the per-request MCP::Server for an authenticated APIKey.
  # Synthwaves APIKeys have no scopes, so every tool is registered;
  # user scoping happens inside each tool via server_context.
  class Server
    VERSION = "1.1.0"

    INSTRUCTIONS = <<~TEXT.freeze
      Synthwaves is a self-hosted music streaming library. These tools manage
      the authenticated user's personal library: search and browse artists,
      albums, and tracks; create and organize playlists; favorite items;
      upload audio; and import YouTube playlists.

      Reads are safe. Writes mutate the real library immediately — creating,
      renaming, and deleting playlists, adding/removing/reordering playlist
      tracks, favoriting, and uploading audio all take effect at once.
      Deleting a playlist never deletes its tracks.

      Key facts:
      - All IDs are per-user. "Record not found" means the ID does not exist
        in this user's library.
      - get_playlist returns playlist_track_id values. Pass those (not track
        IDs) to remove_playlist_track(s) and reorder_playlist.
      - Tracks from import_youtube_playlist have has_audio=false: that tool
        imports metadata only. The server does not download YouTube audio
        (datacenter IPs are bot-checked); audio is pushed later by a separate
        local process, so freshly imported music is not playable yet.
      - upload_track expects base64-encoded audio bytes. Embedded tags are
        read automatically; explicit metadata arguments override them.

      Efficient workflow for large playlists (hundreds/thousands of tracks):
      - Read with get_playlist using compact=true and page/per_page (max 500
        per page).
      - Resolve song names to track IDs in bulk with match_tracks — never one
        search call per song.
      - replace_playlist_tracks sets a playlist's exact contents from an
        ordered track_ids array in one call; remove_playlist_tracks removes
        many entries at once.
    TEXT

    def self.for(api_key)
      new(api_key).build
    end

    def initialize(api_key)
      @api_key = api_key
    end

    def build
      MCP::Server.new(
        name: "synthwaves",
        version: VERSION,
        instructions: INSTRUCTIONS,
        tools: Tools::ALL,
        server_context: {user: api_key.user, api_key: api_key}
      )
    end

    private

    attr_reader :api_key
  end
end
