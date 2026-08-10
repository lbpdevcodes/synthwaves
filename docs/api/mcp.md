# MCP Server

synthwaves.fm exposes a [Model Context Protocol](https://modelcontextprotocol.io) (MCP) server so AI agents (Claude Code, Claude Desktop, and other MCP clients) can manage your music library: search and browse the catalog, create and organize playlists, favorite items, upload audio, and import YouTube playlists.

## Endpoint

```
POST /mcp
```

The server speaks **JSON-RPC 2.0 over stateless HTTP** (Streamable HTTP without SSE):

- A fresh server instance handles every request — revoking an API key takes effect on the very next call.
- Notifications (requests without an `id`) return `202 Accepted` with an empty body.
- Non-POST methods return `405 Method Not Allowed` (`Allow: POST`).
- JSON-RPC batch arrays are supported.
- Responses are `application/json`. Tool results are text content containing compact JSON; expected failures (validation errors, unknown IDs) come back as `isError: true` tool results with HTTP 200.

## Authentication

HTTP Basic with your API key credentials — `client_id` as the username, `secret_key` as the password:

```
Authorization: Basic base64(client_id:secret_key)
```

Create a key in the web UI at `/api_keys`. Failed auth returns `401` with a JSON-RPC error body (code `-32001`). Requests are rate-limited to 60 per minute per key (code `-32000`, HTTP 429).

### Client configuration

Claude Code:

```bash
claude mcp add --transport http synthwaves https://synthwaves.fm/mcp \
  --header "Authorization: Basic $(printf '%s' 'bc_your_client_id:your_secret_key' | base64)"
```

Claude Desktop (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "synthwaves": {
      "type": "http",
      "url": "https://synthwaves.fm/mcp",
      "headers": {
        "Authorization": "Basic <base64(client_id:secret_key)>"
      }
    }
  }
}
```

## Tools

All IDs are per-user. Every tool resolves records through the authenticated key's user, so an ID belonging to another user returns "Record not found" as an `isError` result.

### Library

| Tool           | Description                                                                        |
| -------------- | ---------------------------------------------------------------------------------- |
| `search`       | Search artists, albums, and tracks by title fragment (genre/year/favorites filters) |
| `match_tracks` | Resolve many `"Artist - Title"` or bare-title queries to track IDs in one call (max 200 per call) |
| `list_artists` | List artists (`q`, `category`, sort, limit)                                         |
| `get_artist`   | One artist with their albums                                                        |
| `list_albums`  | List albums (`q`, `artist_id`, sort, limit)                                         |
| `get_album`    | One album with tracks in disc/track order and total duration                        |
| `list_tracks`  | List tracks (`q` full-text, `album_id`, `artist_id`, `genre`, sort, limit)          |
| `get_track`    | One track with full detail (`has_audio`, lyrics, download status, loudness)         |

### Playlists

| Tool                        | Description                                                                  |
| --------------------------- | ---------------------------------------------------------------------------- |
| `list_playlists`            | List playlists with track counts                                              |
| `get_playlist`              | One playlist with tracks in position order, each carrying `playlist_track_id`. Optional `compact` (flat rows), `page`/`per_page` (max 500) for large playlists |
| `create_playlist`           | Create a playlist, optionally seeded with `track_ids` in the given order      |
| `update_playlist`           | Rename a playlist                                                             |
| `delete_playlist`           | Delete a playlist (tracks are never deleted)                                  |
| `add_tracks_to_playlist`    | Add tracks by `track_ids` (in order) or `album_id` (disc/track order)         |
| `remove_playlist_track`     | Remove one entry by `playlist_track_id` (NOT the track ID)                    |
| `remove_playlist_tracks`    | Remove many entries by `playlist_track_ids` or `track_ids` (removes every matching entry) |
| `reorder_playlist`          | Rewrite the full order from an array of `playlist_track_ids`                  |
| `replace_playlist_tracks`   | Set the exact full contents from an ordered `track_ids` array in one call (empty array clears; fails without changes on unknown IDs) |
| `create_playlist_from_album`| Create a playlist containing every track of an album                          |

### Favorites

| Tool            | Description                                                        |
| --------------- | ------------------------------------------------------------------ |
| `list_favorites` | List favorites, filterable by `type` (`Track`/`Album`/`Artist`)    |
| `favorite`       | Favorite a record (idempotent)                                     |
| `unfavorite`     | Unfavorite a record (idempotent — `removed: false` if absent)      |

### Uploads & imports

| Tool                      | Description                                                                  |
| ------------------------- | ---------------------------------------------------------------------------- |
| `upload_track`            | Upload base64-encoded audio (max ~50 MB decoded) as a new track. Embedded tags are read automatically; explicit metadata arguments override them. Conversion, loudness analysis, search indexing, and MusicBrainz enrichment run in the background. |
| `import_youtube_playlist` | Import a YouTube playlist's **metadata only** — tracks have `has_audio=false`. The server does not download YouTube audio (datacenter IPs are bot-checked); audio is pushed later by the local `bin/import_audio` CLI. |

## Notes

- **Upload size**: `upload_track` caps decoded audio at ~50 MB (≈67 MB of base64 in the JSON body). Reverse proxies may impose their own request-body limits.
- **Writes take effect immediately.** Deleting a playlist never deletes its tracks.
- The implementation lives in `app/services/agent_gateway/` (`AgentGatewayController` + `MCP::Server` from the `mcp` gem).

### Large playlists

For playlists with hundreds or thousands of tracks, keep payloads and call counts small:

1. Read with `get_playlist` using `compact=true` and `page`/`per_page` (max 500 per page). Compact rows carry `position`, `playlist_track_id`, `track_id`, `title`, `artist`, `duration`.
2. Resolve song names to track IDs in bulk with `match_tracks` — never one `search` call per song.
3. Rewrite contents with `replace_playlist_tracks` (exact ordered `track_ids` array, one call) or remove batches with `remove_playlist_tracks`.

`replace_playlist_tracks` changes every `playlist_track_id`, so re-fetch before calling `remove_playlist_track(s)` or `reorder_playlist`.
