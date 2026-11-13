# Import API

Endpoints for importing tracks, videos, video subtitles, and playlists, and for uploading files to storage in one PUT or, over 5 GB, in parts. All endpoints require JWT Bearer token authentication (see [Authentication](authentication.md)).

## POST `/api/import/direct_uploads`

Create a presigned direct upload URL for uploading files directly to storage.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filename` | string | Yes | Name of the file being uploaded |
| `byte_size` | integer | Yes | File size in bytes |
| `checksum` | string | Yes | Base64-encoded MD5 checksum of the file |
| `content_type` | string | No | MIME type (default: `video/mp4`) |

### Request

```bash
curl -X POST https://your-server/api/import/direct_uploads \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "song.mp3",
    "byte_size": 5242880,
    "checksum": "rL0Y20zC+Fzt72VPzMSk2A==",
    "content_type": "audio/mpeg"
  }'
```

### Response — 201 Created

```json
{
  "signed_id": "eyJfcmFpbHMiOnsi...",
  "direct_upload": {
    "url": "https://storage.example.com/uploads/...",
    "headers": {
      "Content-Type": "audio/mpeg",
      "Content-MD5": "rL0Y20zC+Fzt72VPzMSk2A=="
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `signed_id` | string | Signed blob ID to pass to track/video import |
| `direct_upload.url` | string | PUT URL for uploading the file |
| `direct_upload.headers` | object | Headers to include with the PUT request |

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 422 | `{"error": "..."}` | Invalid parameters |

---

## Uploads in parts: `/api/import/multipart_upload`

Storage takes at most 5 GB in one PUT. A larger file goes up as an S3 multipart upload: start it, PUT each part to a URL signed for that part, then join the parts. The joined blob is filed like a direct upload's, by its `signed_id`. `bin/import_video` does this for any file over 5 GB. The server's storage must be S3-style; Disk storage answers 422.

Every failure answers `422 {"error": "..."}` naming the reason: a missing parameter, an invalid `signed_id`, a part number outside 1–10000, storage that takes no uploads in parts, or a joined object of the wrong size.

### POST `/api/import/multipart_upload`

Creates the blob and starts its upload.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filename` | string | Yes | Name of the file being uploaded |
| `byte_size` | integer | Yes | File size in bytes |
| `checksum` | string | Yes | Base64-encoded MD5 checksum of the whole file |
| `content_type` | string | No | MIME type (default: `video/mp4`) |

**Response — 201 Created**

```json
{"signed_id": "eyJfcmFpbHMiOnsi...", "upload_id": "2~nJTc...", "part_size": 104857600}
```

Split the file into `part_size` parts, numbered from 1; the last part holds what is left. `part_size` is 100 MiB, or larger when 100 MiB parts would need more than 10,000.

### POST `/api/import/multipart_upload/parts`

Signs one part's PUT. Ask just before sending the part: the URL expires after 5 minutes. A part that fails can be signed and sent again.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `signed_id` | string | Yes | From the start reply |
| `upload_id` | string | Yes | From the start reply |
| `part_number` | integer | Yes | 1 to 10000 |
| `byte_size` | integer | Yes | The part's size in bytes |
| `checksum` | string | Yes | Base64-encoded MD5 checksum of the part |

**Response — 201 Created**

```json
{"url": "https://storage.example.com/...&partNumber=1&uploadId=...", "headers": {"Content-MD5": "rL0Y20zC+Fzt72VPzMSk2A=="}}
```

PUT exactly the part's bytes to `url` with `headers` and a `Content-Length`. The URL signs both the size and the checksum, so storage refuses other bytes with `400 BadDigest`. Keep the `ETag` header storage answers with.

### POST `/api/import/multipart_upload/completion`

Joins the parts, in part-number order, and checks that storage holds the file's whole `byte_size`; an object of any other size is deleted and refused.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `signed_id` | string | Yes | From the start reply |
| `upload_id` | string | Yes | From the start reply |
| `parts` | array | Yes | `[{"part_number": 1, "etag": "\"a9b4...\""}, ...]`, one per part |

**Response — 200 OK**: `{"signed_id": "eyJfcmFpbHMiOnsi..."}`. Pass it as `signed_blob_id` to `POST /api/import/videos`.

### DELETE `/api/import/multipart_upload?signed_id=...&upload_id=...`

Throws away the parts sent so far. Storage bills unfinished parts and lists them nowhere, so abort an upload you will not finish. **Response — 204 No Content.**

---

## POST `/api/import/tracks`

Import a track. Supports two upload modes: direct upload (using a previously uploaded blob) or multipart file upload.

### Mode 1: Direct Upload

Use after obtaining a `signed_id` from the direct uploads endpoint.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `signed_blob_id` | string | Yes | Signed blob ID from direct upload |
| `title` | string | No | Track title (falls back to filename) |
| `artist` | string | No | Artist name (default: `Unknown Artist`) |
| `album` | string | No | Album title (default: `Unknown Album`) |
| `year` | integer | No | Release year |
| `genre` | string | No | Genre |
| `track_number` | integer | No | Track number |
| `disc_number` | integer | No | Disc number |
| `duration` | float | No | Duration in seconds |
| `bitrate` | integer | No | Bitrate in kbps |
| `file_format` | string | No | File format (e.g., `mp3`, `flac`) |
| `cover_art` | string | No | Base64-encoded cover art image data |
| `cover_art_mime_type` | string | No | MIME type of cover art (required if `cover_art` provided) |

### Mode 2: Multipart Upload

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `audio_file` | file | Yes | Audio file (multipart form data) |

Metadata is automatically extracted from the audio file tags.

### Request (Direct Upload)

```bash
curl -X POST https://your-server/api/import/tracks \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "signed_blob_id": "eyJfcmFpbHMiOnsi...",
    "title": "My Song",
    "artist": "Artist Name",
    "album": "Album Title",
    "file_format": "mp3"
  }'
```

### Request (Multipart)

```bash
curl -X POST https://your-server/api/import/tracks \
  -H "Authorization: Bearer <token>" \
  -F "audio_file=@/path/to/song.mp3"
```

### Response — 201 Created

```json
{
  "id": 42,
  "title": "My Song",
  "artist": "Artist Name",
  "album": "Album Title",
  "created": true
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Track ID |
| `title` | string | Track title |
| `artist` | string | Artist name |
| `album` | string | Album title |
| `created` | boolean | `true` if new, `false` if duplicate |

A duplicate track (same title, album, artist, and track number with an attached audio file) returns `200` with `"created": false`.

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 422 | `{"error": "audio_file or signed_blob_id is required"}` | Neither upload mode specified |
| 422 | `{"error": "..."}` | Validation failure |
| 503 | `{"error": "Upload failed: ..."}` | Storage error during file attachment |

---

## POST `/api/import/playlists`

Import a playlist by matching track metadata against existing tracks in the library. Matching is case-insensitive on title, artist, and album.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Playlist name (must be unique) |
| `tracks` | array | No | Array of track objects to match |
| `tracks[].title` | string | Yes | Track title |
| `tracks[].artist` | string | Yes | Artist name |
| `tracks[].album` | string | Yes | Album title |

### Request

```bash
curl -X POST https://your-server/api/import/playlists \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Road Trip",
    "tracks": [
      {"title": "Song One", "artist": "Artist A", "album": "Album X"},
      {"title": "Song Two", "artist": "Artist B", "album": "Album Y"}
    ]
  }'
```

### Response — 201 Created

```json
{
  "id": 7,
  "name": "Road Trip",
  "tracks_matched": 1,
  "tracks_not_found": 1,
  "not_found": [
    {"title": "Song Two", "artist": "Artist B", "album": "Album Y"}
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Playlist ID |
| `name` | string | Playlist name |
| `tracks_matched` | integer | Number of tracks successfully matched and added |
| `tracks_not_found` | integer | Number of tracks that couldn't be matched |
| `not_found` | array | Details of unmatched tracks |

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 422 | `{"error": "name is required"}` | Missing playlist name |
| 409 | `{"error": "Playlist 'X' already exists"}` | Duplicate playlist name |

---

## POST `/api/import/videos`

Import a video using a previously uploaded blob from the direct uploads endpoint.

`bin/import_video PATH` drives the whole flow (direct upload, streamed PUT to storage, then this call) for one local file.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `signed_blob_id` | string | Yes | Signed blob ID from direct upload |
| `title` | string | No | Video title (falls back to filename) |
| `folder_name` | string | No | The folder to file it in, found by name at any depth (folders can sit inside other folders). Created at the top level when no folder has the name. A name several folders share is refused. |
| `season_number` | integer | No | Season number |
| `episode_number` | integer | No | Episode number |
| `thumbnail_signed_blob_id` | string | No | Signed blob ID of a JPEG thumbnail, from a direct upload |
| `details` | object | No | What ffprobe reads from the file: `duration` (seconds), `width`, `height`, `video_codec`, `audio_codec`, `audio_channels`, `bitrate` (kb/s), `container` (ffprobe's format name) |

**A file the server keeps as it is is filed ready.** Send a thumbnail and `details` that say `VideoConversionJob` would keep the file as it is: H.264, AAC with 2 channels or fewer, in an MP4 (`VideoConversionStrategy`). The video is then filed `ready` with them, and no conversion job runs, so the server never downloads the file. `bin/import_video` sends both, with the job's own thumbnail command and the fields `VideoMetadataExtractor` reads. Without them, or when the details say the file needs converting, the video is filed `processing`, and the job reads it, converts it if needed, makes the thumbnail and marks it `ready`.

### Request

```bash
curl -X POST https://your-server/api/import/videos \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "signed_blob_id": "eyJfcmFpbHMiOnsi...",
    "title": "Episode 1",
    "folder_name": "My Series",
    "season_number": 1,
    "episode_number": 1
  }'
```

### Response — 201 Created

```json
{
  "id": 15,
  "title": "Episode 1",
  "folder": "My Series",
  "status": "processing"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Video ID |
| `title` | string | Video title |
| `folder` | string | Folder name (null if no folder) |
| `status` | string | `ready` for a file filed with its thumbnail and details (see above), else `processing` |

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 422 | `{"error": "Invalid signed blob ID"}` | Bad or expired `signed_blob_id` or `thumbnail_signed_blob_id` |
| 422 | `{"error": "Several folders are named Season 1: South Park › Season 1 and The Wire › Season 1"}` | `folder_name` names more than one folder. Nothing is filed. |
| 422 | `{"error": "..."}` | Validation failure |

---

## POST `/api/import/videos/:video_id/subtitles`

Add one subtitle file (SRT or WebVTT) to a video the caller owns. The server converts it to WebVTT and the video page offers it to the player as a `<track>`, so it shows in the browser's captions menu.

`bin/import_video` calls this once per subtitle file after it files the video.

The label, language and kind come from the file name, read against the video's own file name: `English.srt` is "English" (`en`), `Canadian.fre.srt` is "French (Canadian)" (`fr`), `SDH.eng.HI.srt` is "English (SDH)" captions, and `Heat.en.srt` beside `Heat.mkv` is "English". A label the video already has gets a number ("English 2").

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filename` | string | Yes | The file's name, read for its label and language |
| `content_base64` | string | Yes | The file's bytes, base64-encoded. UTF-8, UTF-16 with a byte order mark, and Windows-1252 are all read |
| `label` | string | No | The label to show instead of the one read from `filename` |

### Request

```bash
curl -X POST https://your-server/api/import/videos/15/subtitles \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d "{\"filename\": \"Canadian.fre.srt\", \"content_base64\": \"$(base64 < Canadian.fre.srt)\"}"
```

### Response — 201 Created

```json
{
  "id": 3,
  "label": "French (Canadian)",
  "language": "fr",
  "kind": "subtitles"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Subtitle ID |
| `label` | string | What the captions menu shows |
| `language` | string | ISO 639-1 code, or null when the file name names no language |
| `kind` | string | `subtitles`, or `captions` for SDH / hearing-impaired files |

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 404 | | The video does not exist or belongs to someone else |
| 422 | `{"error": "notes.txt: no subtitle cues found"}` | The file holds no SRT or WebVTT cue timings |
