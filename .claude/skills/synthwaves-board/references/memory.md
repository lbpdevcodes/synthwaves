# Assistant memory

Long-lived facts an assistant remembers between conversations.

*4 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `delete_assistant_memory` — write, destructive

Delete one assistant memory document. The assistant forgets the fact.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `memory_id` | integer | yes |  |

### `list_assistant_memories` — read

List assistant memory documents (facts an assistant stored), newest first, with content. Filter by assistant_id.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assistant_id` | integer | no |  |
| `limit` | integer | no |  |

### `memory_search` — read

Search your own saved long-term memories about this user or context. Use this to recall facts you previously stored with memory_write.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assistant_id` | integer | yes | The assistant whose memories to search. |
| `query` | string | yes | What to recall. |

### `memory_write` — write

Save or update a durable memory about this user or context so you can recall it in future conversations. Reuse the same `key` to UPDATE an existing memory instead of creating a duplicate. Store only durable, reusable facts (preferences, stable context, decisions) — not transient details, secrets, or credentials.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assistant_id` | integer | yes | The assistant that owns the memory. |
| `content` | string | yes | The durable fact to remember. |
| `key` | string | yes | A stable memory key. |
