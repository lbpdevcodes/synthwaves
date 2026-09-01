# Projects, boards, columns and cards

The kanban surface. Hierarchy is project -> board -> column -> card. Cards carry comments, checklist items, labels and due dates. list_assignable_people lives here because assignment is mostly a kanban concern, but it serves contacts, tasks and conversations too.

*32 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `add_card_comment` — write

Add a markdown comment to a card.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes | Card ID from list_cards. |
| `content_markdown` | string | yes | GitHub-flavored markdown body. |

### `create_board` — write

Create a board in a project. New boards land last; follow with create_column to set up its columns.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `project_id` | integer | yes |  |
| `assignee_id` | integer or null | no | Person id from list_assignable_people; null unassigns. |

### `create_card` — write

Create a card in a column, optionally assigned to someone.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `column_id` | integer | yes | Column ID from list_columns. |
| `title` | string | yes | Short card title. |
| `assignee_id` | integer or null | no | Person id from list_assignable_people; null unassigns. |
| `card_type` | string (`task` \| `bug` \| `spike` \| `epic`) | no | What kind of work this is. Defaults to task. |
| `description_markdown` | string | no | GitHub-flavored markdown body. |
| `due_on` | string | no | ISO date, for example 2026-08-25. |
| `due_time` | string | no | 24-hour time. Requires due_on. |
| `priority` | string (`urgent` \| `high` \| `medium` \| `low`) | no | How much it matters. Left unset when omitted. |

### `create_checklist_item` — write

Add a checklist item to a card. New items land at the bottom.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes |  |
| `title` | string | yes |  |

### `create_column` — write

Create a column on a board. New columns land rightmost and are active unless a kind is given.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `board_id` | integer | yes |  |
| `name` | string | yes |  |
| `kind` | string (`backlog` \| `active` \| `done`) | no | What the column means: backlog, active, or done. A card moved into a done column is completed. |

### `create_label` — write

Create a label in a project (name plus hex color, e.g. #ef4444).

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `color` | string | yes | Hex color, e.g. #ef4444 |
| `name` | string | yes |  |
| `project_id` | integer | yes |  |

### `create_project` — write

Create a project (a group of kanban boards).

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `assignee_id` | integer or null | no | Person id from list_assignable_people; null unassigns. |
| `key` | string | no | Short prefix for this project's card keys, e.g. GOS gives GOS-42. Derived from the name when omitted. |

### `delete_board` — write, destructive

Delete a board. Its columns and cards are deleted with it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `board_id` | integer | yes |  |

### `delete_card` — write, destructive

Delete a card. Its comments and checklist items are deleted with it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes |  |

### `delete_card_comment` — write, destructive

Delete a card comment.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes |  |
| `comment_id` | integer | yes |  |

### `delete_checklist_item` — write, destructive

Delete a card checklist item.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes |  |
| `item_id` | integer | yes |  |

### `delete_column` — write, destructive

Delete a column. Its cards are deleted with it — move them first with move_card to keep them.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `column_id` | integer | yes |  |

### `delete_label` — write, destructive

Delete a project label and remove it from every card.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `label_id` | integer | yes |  |
| `project_id` | integer | yes |  |

### `delete_project` — write, destructive

Delete a project. Its boards, columns, and cards are deleted with it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `project_id` | integer | yes |  |

### `get_card` — read

Get a card with its description, labels, checklist items, and comments.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes |  |

### `list_assignable_people` — read

List the teammates a card, board, project, contact, task, or conversation can be assigned to. Returns each person's id and name; pass that id as assignee_id when you assign something. Scoped to this tenant's own people.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `limit` | integer | no | Default 50, at most 200. |
| `q` | string | no | Narrow by part of a name or email address. |

### `list_boards` — read

List a project's boards in display order.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `project_id` | integer | yes |  |

### `list_card_comments` — read

List a card's comments, oldest first.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes |  |

### `list_cards` — read

List cards on a board or in one column, optionally only the ones a person holds or that nobody holds.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assignee_id` | integer | no | Only records assigned to this person. |
| `board_id` | integer | no | List across the whole board. |
| `card_type` | string (`task` \| `bug` \| `spike` \| `epic`) | no | Only cards of this kind. |
| `column_id` | integer | no | List one column only. |
| `parent_id` | integer | no | Only the children of this card. |
| `priority` | string (`urgent` \| `high` \| `medium` \| `low`) | no | Only cards at this priority. |
| `status` | string (`open` \| `all`) | no | Default: open. |
| `unassigned` | boolean | no | true lists only records with no assignee. |

### `list_columns` — read

List a board's columns in display order.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `board_id` | integer | yes | Board ID from list_projects. |

### `list_labels` — read

List a project's labels. Labels are project-scoped: one palette serves all of its boards.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `project_id` | integer | yes |  |

### `list_projects` — read

List projects and their boards.

Takes no parameters.

### `move_card` — write

Move a card to a column.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes | Card ID from list_cards. |
| `column_id` | integer | yes | Target column ID. |
| `position` | integer | no | One-based target position. |

### `move_column` — write

Move a column to a one-based position on its board.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `column_id` | integer | yes |  |
| `position` | integer | yes | 1-based slot on the current board |

### `set_card_labels` — write

Replace a card's labels with the given label ids (from the card's project). Pass [] to clear.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes |  |
| `label_ids` | array of integer | yes |  |

### `update_board` — write

Rename a board, or assign it to someone.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `board_id` | integer | yes |  |
| `name` | string | yes |  |
| `assignee_id` | integer or null | no | Person id from list_assignable_people; null unassigns. |

### `update_card` — write

Update a card's title, description, due date, or assignee, or complete/reopen it via operation.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes |  |
| `assignee_id` | integer or null | no | Person id from list_assignable_people; null unassigns. |
| `card_type` | string (`task` \| `bug` \| `spike` \| `epic`) | no | What kind of work this is. |
| `description_markdown` | string | no | Replaces the description; markdown |
| `due_on` | string | no | ISO date, e.g. 2026-08-25 |
| `due_time` | string | no | 24h time, e.g. 09:30; empty clears the time |
| `operation` | string (`complete` \| `reopen`) | no |  |
| `parent_id` | integer or null | no | File this card under a parent, e.g. an epic. Null unfiles it. Cards nest one level deep. |
| `priority` | string (`urgent` \| `high` \| `medium` \| `low`) | no | How much it matters. |
| `title` | string | no |  |

### `update_card_comment` — write

Update a card comment from markdown.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes |  |
| `comment_id` | integer | yes |  |
| `content_markdown` | string | yes | GitHub-flavored markdown body |

### `update_checklist_item` — write

Rename a card's checklist item, or complete/reopen it via operation.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `card_id` | integer | yes |  |
| `item_id` | integer | yes |  |
| `operation` | string (`complete` \| `reopen`) | no |  |
| `title` | string | no |  |

### `update_column` — write

Rename a column, or set what it means: backlog, active or done.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `column_id` | integer | yes |  |
| `kind` | string (`backlog` \| `active` \| `done`) | no | What the column means: backlog, active, or done. A card moved into a done column is completed. |
| `name` | string | no |  |

### `update_label` — write

Update a project label's name, color, or both.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `label_id` | integer | yes |  |
| `project_id` | integer | yes |  |
| `color` | string | no | Hex color, e.g. #0ea5e9 |
| `name` | string | no |  |

### `update_project` — write

Rename a project, or assign it to someone.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `project_id` | integer | yes |  |
| `assignee_id` | integer or null | no | Person id from list_assignable_people; null unassigns. |
| `key` | string | no | Short prefix for this project's card keys, e.g. GOS gives GOS-42. Derived from the name when omitted. |
