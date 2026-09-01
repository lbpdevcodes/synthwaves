# Media storage

Uploaded files and the folders that organise them.

*9 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `create_media_folder` — write

Create a media-library folder. Omit parent_id for a root folder; an unknown parent id is rejected.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `parent_id` | integer | no | Parent folder id; omit for root |

### `create_media_item` — write

Add a file to the media library. Give either url (an https address to download) or data (base64 contents, which also needs filename). Images, documents and code files up to 10 MB; audio and video up to 50 MB.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `content_type` | string | no | Overrides the served or inferred type |
| `data` | string | no | Base64-encoded file contents; requires filename |
| `filename` | string | no | Name to store; required with data, derived from the URL otherwise |
| `folder_id` | integer | no | Folder to file it in; omit for the library root |
| `url` | string | no | https URL to download the file from |

### `delete_media_folder` — write, destructive

Delete a media-library folder. Its files and sub-folders move up one level, never deleted.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `folder_id` | integer | yes |  |

### `delete_media_item` — write, destructive

Delete a file from the media library. The stored file is kept only if a chat message or another record still uses it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `media_item_id` | integer | yes |  |

### `get_media_item` — read

Read one media-library file: filename, type, size, source, folder and a fetchable URL.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `media_item_id` | integer | yes |  |

### `list_media` — read

List files in the media library, newest first. Filter by kind, source, folder, or a filename search. Returns metadata and a fetchable URL per file. Images generated in chat and files sent or received in conversations are saved here automatically — look here before asking anyone to re-upload something.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `folder_id` | integer | no | Only files in this folder |
| `kind` | string (`images` \| `videos` \| `audio` \| `documents`) | no |  |
| `limit` | integer | no | Default 25 |
| `q` | string | no | Filename search |
| `source` | string (`received` \| `sent` \| `generated` \| `uploaded` \| `knowledge` \| `catalog` \| `social`) | no | How the file reached the library |

### `list_media_folders` — read

List the media library's folders by name. parent_id encodes the tree.

Takes no parameters.

### `update_media_folder` — write

Rename a media-library folder, move it under another parent, or both. parent_id null moves it to the root.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `folder_id` | integer | yes |  |
| `name` | string | no |  |
| `parent_id` | integer or null | no | New parent; null moves it to the root |

### `update_media_item` — write

Move a media-library file to another folder. Pass folder_id, or null for the library root.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `media_item_id` | integer | yes |  |
| `folder_id` | integer or null | no | Folder to file it in; null moves it to the root |
