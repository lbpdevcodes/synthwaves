# Inbox conversations

The team inbox for messaging-channel conversations, plus its digest and analytics.

*8 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `assign_conversation` — write

Assign an inbox conversation to a teammate, or pass a null assignee_id to unassign it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assignee_id` | integer or null | yes | Person id from list_assignable_people; null unassigns. |
| `conversation_id` | integer | yes |  |

### `conversation_analytics` — read

Conversation-quality metrics over a time range: totals, escalation/resolution/deflection rates, median first response, volume by platform, busiest hours, top ticket categories.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `range` | string (`24h` \| `7d` \| `30d` \| `90d` \| `all`) | no | Default 30d |

### `create_conversation_note` — write

Add an internal staff note to a conversation from markdown. The note is never shown to the customer, never delivered to the channel, and never read by the assistant.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `content_markdown` | string | yes | GitHub-flavored markdown body |
| `conversation_id` | integer | yes |  |

### `get_conversation` — read

Show one conversation with its trailing message transcript (user and assistant messages only).

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `conversation_id` | integer | yes |  |
| `message_limit` | integer | no | Trailing messages to include (default 20) |

### `inbox_digest` — read

Returns a compact digest of inbox conversation activity: totals, escalations, resolutions, and one line per recent conversation (contact, channel, preview, status). Use it to summarize what happened in the inbox over a period, or to find conversations that have gone quiet.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `idle_for_hours` | integer | no | Only include conversations idle for at least this many hours. |
| `since_hours` | integer | no | How many hours back to include (default 24). |

### `list_conversations` — read

List messaging-channel conversations (the team inbox), most recent first. Filter by status, free text (contact name or external id), assignee, or unread only.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assignee_id` | integer | no | Only records assigned to this person. |
| `limit` | integer | no | Default 20 |
| `q` | string | no | Matches contact name or external id |
| `status` | string (`active` \| `escalated` \| `paused`) | no |  |
| `unassigned` | boolean | no | true lists only records with no assignee. |
| `unread` | boolean | no | Only conversations with unread inbound messages |

### `reply_to_conversation` — write

Send a human reply into a conversation. WARNING: this messages the real customer through the channel and pauses the bot. Confirm with the operator before sending.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `content` | string | yes | The reply text sent to the customer |
| `conversation_id` | integer | yes |  |

### `update_conversation_status` — write

Change a conversation's bot state: pause (a human takes over, bot goes quiet), resolve (bot resumes), or restart (roll over to a fresh chat session; returns the new chat_id).

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `conversation_id` | integer | yes |  |
| `operation` | string (`pause` \| `resolve` \| `restart`) | yes |  |
