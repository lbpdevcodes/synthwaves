# Notes

The Notion-style note tree: notes and the folders that hold them.

*9 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `create_note` — write

Create and ingest a knowledge-base note from markdown. Blocks: "> [!INFO\|WARN\|SUCCESS]" quotes render as callouts and "> [!TOGGLE] Summary" quotes as collapsible toggles. For a daily note, file it in the "Daily Notes" folder with the date (YYYY-MM-DD) as the title.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `content_markdown` | string | yes | GitHub-flavored markdown body |
| `title` | string | yes |  |
| `collection_ids` | array of integer | no | Knowledge collections to file the note in; omit for none |
| `note_folder_id` | integer | no | Folder to file the note in; omit for root |

### `create_note_folder` — write

Create a note folder. Omit parent_id for a root folder; an unknown parent id is rejected.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `parent_id` | integer | no | Parent folder id; omit for root |

### `delete_note` — write, destructive

Move a knowledge-base note to the trash. Its search chunks are removed immediately; restore_note can bring it back within 30 days.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `note_id` | integer | yes |  |

### `get_note` — read

Read one knowledge-base note: markdown content, canonical HTML, and its resolved wikilinks and backlinks.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `note_id` | integer | yes |  |

### `list_note_folders` — read

List note folders as a flat list, ordered by name. parent_id encodes the tree; null means a root folder.

Takes no parameters.

### `list_notes` — read

List knowledge-base notes, ordered by title. Metadata only — call get_note with a note id to read its content.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `archived` | boolean | no | true: only archived notes; false: exclude them. Omit for all |
| `folder_id` | integer | no | Only notes filed in this folder |
| `limit` | integer | no | Default 50 |
| `pinned` | boolean | no | true: only pinned notes |
| `query` | string | no | Full-text search over note titles and bodies |

### `restore_note` — write

Restore a note from the trash. It becomes searchable again and open [[wikilinks]] to its title re-adopt it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `note_id` | integer | yes |  |

### `update_note` — write

Update a knowledge-base note. Only the provided fields change: title, content_markdown (re-rendered to HTML and re-ingested; "> [!INFO\|WARN\|SUCCESS]" quotes render as callouts, "> [!TOGGLE] Summary" as collapsible toggles), note_folder_id (null moves to root), collection_ids (replaces all).

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `note_id` | integer | yes |  |
| `archived` | boolean | no | Archive or unarchive the note (archived notes stay searchable) |
| `collection_ids` | array of integer | no | Replaces the note's knowledge collections |
| `content_markdown` | string | no | GitHub-flavored markdown body |
| `note_folder_id` | integer or null | no | Folder to file the note in; null for root |
| `pinned` | boolean | no | Pin or unpin the note in the list pane |
| `template` | boolean | no | Make or unmake the note a template. Templates keep the editor but leave search, RAG and wikilink resolution |
| `title` | string | no |  |

### `update_note_folder` — write

Rename a note folder or move it within the tree. Only the provided fields change; a null parent_id moves the folder to root. An unknown parent id is rejected.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `folder_id` | integer | yes |  |
| `name` | string | no |  |
| `parent_id` | integer or null | no | New parent folder id; null for root |
