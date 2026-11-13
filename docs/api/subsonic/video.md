# Video

These endpoints extend the Subsonic API with video management capabilities.

## `getVideos`

Returns a list of videos, optionally filtered by folder or search query.

**Path:** `/rest/getVideos`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `folderId` | string | No | Filter by folder ID |
| `query` | string | No | Search query to filter videos |

Only videos with `ready` status are returned.

### Response

```json
{
  "subsonic-response": {
    ...
    "videos": {
      "video": [
        {
          "id": "15",
          "title": "Episode 1",
          "duration": 3600,
          "width": 1920,
          "height": 1080,
          "size": 1073741824,
          "contentType": "video/mp4",
          "fileFormat": "mp4",
          "folderId": "3",
          "folderName": "My Series",
          "episodeNumber": 1,
          "seasonNumber": 1,
          "created": "2024-01-15T10:30:00Z"
        }
      ]
    }
  }
}
```

Videos use the standard [video shape](README.md#video).

---

## `getVideo`

Returns details for a single video.

**Path:** `/rest/getVideo`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Video ID |

### Response

```json
{
  "subsonic-response": {
    ...
    "video": {
      "id": "15",
      "title": "Episode 1",
      "duration": 3600,
      ...
      "subtitles": [
        {"id": "4", "label": "English (SDH)", "language": "en", "kind": "captions"},
        {"id": "3", "label": "French", "language": "fr", "kind": "subtitles"}
      ]
    }
  }
}
```

Uses the standard [video shape](README.md#video), plus `subtitles`: the video's subtitle tracks by label, `[]` when it has none. `language` (an ISO 639-1 code) is left out when the file name didn't give one, and `kind` is `subtitles` or `captions`. Only `getVideo` lists them, so `getVideos` and `getFolder` don't read every track of every video. Fetch a track's text with [`getVideoSubtitle`](#getvideosubtitle).

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Video not found | Invalid video ID |

---

## `getVideoSubtitle`

Returns one subtitle track of a video as WebVTT (`text/vtt`), the format the server stores every track in (SRT uploads are converted).

**Path:** `/rest/getVideoSubtitle`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `videoId` | string | Yes | Video ID |
| `id` | string | Yes | Subtitle ID, from the video's `subtitles` in [`getVideo`](#getvideo) |

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Subtitle not found | The video isn't the user's, or the subtitle isn't that video's |

---

## `videoStream`

Streams the video file. Redirects to the video file URL. Only videos with `ready` status can be streamed.

**Path:** `/rest/videoStream`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Video ID |

### Response

Returns a `302` redirect to the video file URL.

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Video not found | Invalid video ID, not ready, or no file attached |

---

## `getVideoThumbnail`

Returns the thumbnail image for a video. Optionally resize to a specific size.

**Path:** `/rest/getVideoThumbnail`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Video ID |
| `size` | integer | No | Resize to square dimensions (e.g., `200` for 200x200) |

### Response

Returns a `302` redirect to the thumbnail image URL. If `size` is specified, redirects to a resized variant. Returns `404` if no thumbnail is attached.

### Errors

Returns HTTP `404` (not a Subsonic error envelope) if the video or thumbnail is not found.

---

## `savePlaybackPosition`

Saves the current playback position for a video. Used for resume functionality.

**Path:** `/rest/savePlaybackPosition`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Video ID |
| `position` | float | Yes | Playback position in seconds |

### Response

Returns an empty success response.

```json
{
  "subsonic-response": {
    "status": "ok",
    "version": "1.16.1",
    ...
  }
}
```

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Video not found | Invalid video ID |

---

## `getPlaybackPosition`

Returns the saved playback position for a video. Returns `0` if no position has been saved.

**Path:** `/rest/getPlaybackPosition`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Video ID |

### Response

```json
{
  "subsonic-response": {
    ...
    "playbackPosition": {
      "id": "15",
      "position": 1234.5
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Video ID |
| `position` | float | Playback position in seconds (0 if never saved) |

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Video not found | Invalid video ID |

---

## `getFolders`

Returns every one of the user's video folders, sorted by name, as one flat list. A folder can sit inside another; `parentId` says which, so a client can rebuild the tree.

**Path:** `/rest/getFolders`

**Parameters:** [Common params](README.md#required-common-parameters) only.

### Response

```json
{
  "subsonic-response": {
    ...
    "folders": {
      "folder": [
        {
          "id": "3",
          "name": "My Series",
          "description": "Two seasons",
          "parentId": "1",
          "videoCount": 12,
          "created": "2026-11-12T10:30:00Z"
        }
      ]
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Folder ID |
| `name` | string | Folder name, unique among the folders in the same parent |
| `description` | string | Folder description. Left out when there is none. |
| `parentId` | string | The folder this one sits inside. Left out for a top-level folder. |
| `videoCount` | integer | Number of ready videos in the folder itself, not counting its subfolders |
| `created` | string | When the folder was created (ISO 8601) |

A folder's cover is served by [`getFolderCover`](#getfoldercover).

---

## `getFolder`

Returns a folder with its videos.

**Path:** `/rest/getFolder`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Folder ID |

### Response

```json
{
  "subsonic-response": {
    ...
    "folder": {
      "id": "3",
      "name": "My Series",
      "description": "Two seasons",
      "videoCount": 2,
      "created": "2026-11-12T10:30:00Z",
      "video": [
        {
          "id": "15",
          "title": "Episode 1",
          "duration": 3600,
          ...
        }
      ]
    }
  }
}
```

The [`getFolders`](#getfolders) fields, plus `video`: the folder's ready videos in season and episode order, in the standard [video shape](README.md#video).

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Folder not found | Invalid folder ID, or another user's folder |

---

## `createFolder`

Creates a folder, optionally moving videos into it. A video can be in one folder at a time, so a video already in another folder moves.

**Path:** `/rest/createFolder`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Folder name, unique among the folders in the same parent |
| `description` | string | No | Folder description |
| `parentId` | string | No | A folder to create it inside. Left out, the folder is top-level. |
| `videoId` | string | No | A video to move into the new folder. Repeat it for several: `videoId=15&videoId=16` (`videoId[]=15` works too). |

### Response

The new folder, in the [`getFolder`](#getfolder) shape.

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 10 | Required parameter is missing: name | `name` is missing or blank |
| 0 | Name has already been taken | The parent already holds a folder with this name |
| 70 | Folder not found | `parentId` isn't one of the user's folders. Nothing is created. |
| 70 | Video not found | A `videoId` isn't one of the user's videos. Nothing is created. |

---

## `updateFolder`

Renames or re-describes a folder, moves it inside another, and moves videos into and out of it. Every change in one call applies together, or none does.

**Path:** `/rest/updateFolder`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Folder ID |
| `name` | string | No | New name. Left unchanged when not sent. |
| `description` | string | No | New description. Sent empty, it clears the description; not sent, it stays. |
| `parentId` | string | No | The folder to move it inside. Sent empty, the folder moves to the top level; not sent, it stays where it is. |
| `videoIdToAdd` | string | No | A video to move into the folder, out of any other. Repeatable. |
| `videoIdToRemove` | string | No | A video to take out of the folder. Repeatable. A video that isn't in this folder is left where it is. |

### Response

The updated folder, in the [`getFolder`](#getfolder) shape.

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 10 | Required parameter is missing: id | `id` is missing |
| 70 | Folder not found | Invalid folder ID or `parentId`, or another user's folder |
| 70 | Video not found | A `videoIdToAdd` or `videoIdToRemove` isn't one of the user's videos. Nothing changes. |
| 0 | Name can't be blank | `name` was sent empty. Nothing changes. |
| 0 | Name has already been taken | Another folder in the same parent has this name. Nothing changes. |
| 0 | TV can't go inside itself or anything inside it | `parentId` is the folder itself or a folder inside it. Nothing changes. |

---

## `deleteFolder`

Deletes a folder. What it holds moves up one level: its videos and subfolders go into the folder it sat inside, or, for a top-level folder, its videos leave every folder and its subfolders become top-level.

**Path:** `/rest/deleteFolder`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Folder ID |

### Response

Returns an empty success response.

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 10 | Required parameter is missing: id | `id` is missing |
| 70 | Folder not found | Invalid folder ID, or another user's folder |
| 0 | Can't delete South Park: TV already has one named Season 1. | A subfolder would land beside a folder of the same name. Nothing is deleted. |

---

## `getFolderCover`

Returns a folder's cover image: the cover set on the web, or else the thumbnail of its first ready video in episode order, or else the first cover among its subfolders, by name. Optionally resize to a specific size.

**Path:** `/rest/getFolderCover`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Folder ID |
| `size` | integer | No | Resize to square dimensions (e.g., `200` for 200x200) |

### Response

Returns a `302` redirect to the image URL, or to a resized variant when `size` is given.

### Errors

Returns HTTP `404` (not a Subsonic error envelope) when the folder isn't found or has neither a cover nor a video thumbnail, the same as [`getVideoThumbnail`](#getvideothumbnail).
