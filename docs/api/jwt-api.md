# JWT API v1

Token exchange, native app bootstrap, and the library management endpoints the native apps use.

Every endpoint except the two token exchanges, `/api/v1/native/credentials` and the two code sign-in endpoints needs an `Authorization: Bearer <token>` header. Records belong to one user, so another user's ID is a 404.

## POST `/api/v1/auth/token`

Exchange API key credentials for a JWT.

**Auth:** None (this is the auth endpoint)

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `client_id` | string | Yes | API key client ID (format: `bc_` + 32 hex chars) |
| `secret_key` | string | Yes | API key secret |

### Request

```bash
curl -X POST https://your-server/api/v1/auth/token \
  -H "Content-Type: application/json" \
  -d '{"client_id": "bc_a1b2c3d4e5f6...", "secret_key": "sk_..."}'
```

### Response — 200 OK

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "expires_in": 3600
}
```

| Field | Type | Description |
|-------|------|-------------|
| `token` | string | HS256 JWT, valid for 1 hour |
| `expires_in` | integer | Token lifetime in seconds |

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 401 | `{"error": "Invalid credentials"}` | Wrong `client_id` or `secret_key` |
| 401 | `{"error": "API key has expired"}` | Key past expiration date |

---

## POST `/api/v1/auth/native_token`

Exchange the email and Subsonic password the native apps already hold for a JWT, so they can reach this API without an API key.

**Auth:** None (this is the auth endpoint)

The credentials are read from the request body only. Values in the query string are ignored, so a leaked Subsonic stream URL cannot mint a token.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `email` | string | Yes | Account email |
| `subsonic_password` | string | Yes | The account's Subsonic password |

### Request

```bash
curl -X POST https://your-server/api/v1/auth/native_token \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "subsonic_password": "..."}'
```

### Response — 200 OK

Same as [`POST /api/v1/auth/token`](#post-apiv1authtoken).

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 401 | `{"error": "Invalid credentials"}` | Wrong email or password, or the account has no Subsonic password |
| 429 | `{"error": "Too many attempts. Try again later."}` | More than 10 attempts for one email in 3 minutes |

---

## GET `/api/v1/native/credentials`

Returns the current user's credentials for configuring Subsonic clients. Intended for native app bootstrap flows.

**Auth:** Web session (cookie-based, not JWT)

### Request

```bash
curl https://your-server/api/v1/native/credentials \
  -b "session_cookie=..."
```

### Response — 200 OK

```json
{
  "email": "user@example.com",
  "subsonic_password": "abc123",
  "theme": "synthwave"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `email` | string | User's email address (used as Subsonic username) |
| `subsonic_password` | string | Password for Subsonic API authentication |
| `theme` | string | User's selected theme (`synthwave`, `reggae`, `punk`, or `jazz`) |

---

## Code sign-in for TVs

A TV can't easily type a password, so it signs in with a code instead:

1. The TV asks for a code with `POST /api/v1/device_sign_ins` and shows the `code`, with a QR code of `url_with_code`.
2. Someone signed in on the web opens `/link` (the QR code fills the code in), enters the code and presses **Sign In**. The page names the TV that asked.
3. The TV checks in with its `secret` every `interval` seconds at `POST /api/v1/device_sign_in_claim`. Once the code is entered, it gets the account's email and Subsonic password, exactly once.

A code lasts 10 minutes and can be entered once. The server stores only a SHA-256 digest of the secret. Both endpoints answer with `Cache-Control: no-store` and read only the request body.

### POST `/api/v1/device_sign_ins`

**Auth:** None

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `device_name` | string | No | What the TV calls itself, shown on the `/link` button (squished to 40 characters; `TV` when blank) |

```bash
curl -X POST https://your-server/api/v1/device_sign_ins \
  -H "Content-Type: application/json" \
  -d '{"device_name": "Apple TV"}'
```

#### Response — 201 Created

```json
{
  "code": "KQ7M-4TRH",
  "secret": "a 43-character URL-safe secret",
  "url": "https://your-server/link",
  "url_with_code": "https://your-server/link?code=KQ7M-4TRH",
  "expires_in": 600,
  "interval": 5
}
```

Codes use `BCDFGHJKLMNPQRSTVWXZ23456789`: no vowels, and no 0, O, 1 or I. `/link` takes them in any case, with or without the dash.

| Status | Body | Cause |
|--------|------|-------|
| 429 | `{"error": "Too many attempts. Try again later."}` | More than 10 codes for one IP address in 10 minutes |

### POST `/api/v1/device_sign_in_claim`

**Auth:** None (the secret is the credential)

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `secret` | string | Yes | The `secret` from `POST /api/v1/device_sign_ins` |

```bash
curl -X POST https://your-server/api/v1/device_sign_in_claim \
  -H "Content-Type: application/json" \
  -d '{"secret": "..."}'
```

| Status | Body | Meaning |
|--------|------|---------|
| 202 | `{"status": "pending"}` | Nobody has entered the code yet. Check in again after `interval` seconds. |
| 200 | `{"email": "user@example.com", "subsonic_password": "..."}` | Signed in. The sign-in is deleted as it answers, so this comes once. |
| 404 | `{"error": "This code has expired. Get a new one on the TV."}` | The code expired, was already claimed, or the secret is wrong. Ask for a new code. |
| 429 | `{"error": "Too many attempts. Try again later."}` | More than 30 check-ins from one IP address in a minute |

---

## Library management

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 401 | `{"error": "Unauthorized"}` | Missing, invalid, or expired token |
| 404 | `{"error": "Not found"}` | No such record in this user's library |
| 422 | `{"errors": ["Title can't be blank"]}` | Validation failed |
| 422 | `{"error": "..."}` | The request can't be carried out, such as merging a record into itself |

### Tracks

| Method | Path | Body | Returns |
|--------|------|------|---------|
| GET | `/api/v1/tracks/:id` | | Track, with `tags` |
| PATCH | `/api/v1/tracks/:id` | `{"track": {...}}` | Track, with `tags` |
| DELETE | `/api/v1/tracks/:id` | | 204, and the audio file is deleted |

`PATCH` accepts `title`, `artist_name`, `album_title`, `track_number`, `disc_number`, `release_year`, `language`, `content_rating`, and `lyrics`.

- Artist and album are typed names. A name that doesn't exist yet is created, and a blank name keeps the current one.
- Changing the artist moves the track to an album of the same title under the new artist.
- A `release_year` of `null` or `""` clears the year.

```json
{
  "id": 12,
  "title": "Nightcall",
  "track_number": 1,
  "disc_number": 1,
  "duration": 258.0,
  "bitrate": 320,
  "file_format": "mp3",
  "file_size": 10312000,
  "lyrics": null,
  "language": "en",
  "release_year": 2010,
  "content_rating": "clean",
  "created_at": "2026-11-05T10:00:00Z",
  "has_audio": true,
  "artist": {"id": 3, "name": "Kavinsky"},
  "album": {"id": 7, "title": "OutRun"},
  "tags": [{"tagging_id": 41, "name": "synthwave", "tag_type": "genre"}]
}
```

### Albums

| Method | Path | Body | Returns |
|--------|------|------|---------|
| POST | `/api/v1/albums` | `{"album": {...}}` | 201 and the album |
| PATCH | `/api/v1/albums/:id` | `{"album": {...}}` | Album |
| DELETE | `/api/v1/albums/:id` | | 204, and its tracks and their audio are deleted |
| PUT | `/api/v1/albums/:id/cover` | Multipart `cover_image` | Album |
| DELETE | `/api/v1/albums/:id/cover` | | Album |
| POST | `/api/v1/albums/:id/merge` | `{"source_album_id": 8}` | The surviving album |

`POST` and `PATCH` accept `title`, `artist_name` or `artist_id`, `year`, and `genre`. Changing an album's artist moves its tracks to that artist.

`PUT .../cover` accepts JPEG, PNG, GIF, or WebP, judged from the file's contents. Anything else is a 422.

### Artists

| Method | Path | Body | Returns |
|--------|------|------|---------|
| POST | `/api/v1/artists` | `{"artist": {...}}` | 201 and the artist |
| PATCH | `/api/v1/artists/:id` | `{"artist": {...}}` | Artist |
| DELETE | `/api/v1/artists/:id` | | 204, and its albums, tracks, and audio are deleted |
| POST | `/api/v1/artists/:id/merge` | `{"source_artist_id": 8}` | The surviving artist |

`POST` and `PATCH` accept `name` and `category` (`music` or `podcast`).

### Playlists

| Method | Path | Body | Returns |
|--------|------|------|---------|
| GET | `/api/v1/playlists/:id` | | Playlist with one page of `tracks` |
| POST | `/api/v1/playlists` | `{"playlist": {"name": "..."}, "track_ids": [1, 2]}` | 201 and the playlist |
| PATCH | `/api/v1/playlists/:id` | `{"playlist": {"name": "..."}}` | Playlist |
| DELETE | `/api/v1/playlists/:id` | | 204, and its tracks are kept |
| POST | `/api/v1/playlists/:id/tracks` | `{"track_ids": [1, 2]}` | `{"added": 2, "tracks_count": 9}` |
| DELETE | `/api/v1/playlists/:id/tracks/:playlist_track_id` | | 204 |
| PATCH | `/api/v1/playlists/:id/track_order` | `{"playlist_track_ids": [5, 4, 6]}` | `{"reordered": 3}` |
| POST | `/api/v1/playlists/:id/merge` | `{"source_playlist_id": 8}` | The surviving playlist |

`GET` returns up to 100 rows per page through `page` and `per_page`. Each row has `position`, `playlist_track_id`, and a `track` with `id`, `title`, `duration`, `has_audio`, `artist`, and `album`.

`POST .../tracks` skips tracks already in the playlist.

`track_order` must list every entry in the playlist exactly once. Anything else is a 422, which also means the playlist changed since it was read.

### Merging

The record in the path survives and the source is destroyed.

- Albums: tracks move to the surviving album and its artist. The cover carries over if the survivor has none. The survivor keeps its year and genre.
- Artists: albums, tracks, and favorites move. Albums with the same title are merged.
- Playlists: tracks not already in the survivor are appended.

Same-titled tracks are not deduplicated.

### Genre tags

| Method | Path | Body | Returns |
|--------|------|------|---------|
| POST | `/api/v1/taggings` | `{"name": "synthwave", "tag_type": "genre", "taggable_type": "Track", "taggable_id": 12}` | 201 and the tagging |
| DELETE | `/api/v1/taggings/:id` | | 204 |

`taggable_id` must belong to this user's library.
