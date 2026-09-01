# Contacts and opportunities

People, the opportunities attached to them, and their follow-up tasks. These tasks are CRM follow-ups, not kanban cards.

*9 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `capture_opportunity` — write

Captures a new sales opportunity: finds or creates the CRM contact by email and records their inquiry as an internal note. Use for inbound leads from forms and workflows.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `email` | string | yes | The lead's email address. |
| `company` | string | no | The lead's company or organization. |
| `inquiry` | string | no | The lead's inquiry in their own words. |
| `name` | string | no | The lead's full name. |

### `create_contact` — write

Create a CRM contact. identities is a list of {kind, value} with kind email, phone, or handle ("platform:id"); values normalize (case-folded emails, digit-only phones).

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assignee_id` | integer or null | no | Person id from list_assignable_people; null unassigns. |
| `deal_value` | number | no |  |
| `identities` | array of object | no |  |
| `name` | string | no |  |
| `tags` | array of string | no |  |

### `create_contact_task` — write

Create a follow-up task on a contact ("call back Tuesday"), optionally with a due date.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `contact_id` | integer | yes |  |
| `title` | string | yes |  |
| `assignee_id` | integer or null | no | Person id from list_assignable_people; null unassigns. |
| `due_on` | string | no | ISO date, e.g. 2026-08-25 |

### `list_contact_tasks` — read

List a contact's follow-up tasks. status open (default), completed, or all.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `contact_id` | integer | yes |  |
| `assignee_id` | integer | no | Only records assigned to this person. |
| `status` | string (`open` \| `completed` \| `all`) | no |  |
| `unassigned` | boolean | no | true lists only records with no assignee. |

### `merge_contacts` — write, destructive

Merge loser into winner: the loser's identities, chats, conversations, and leads move to the winner, then the loser is destroyed. WARNING: irreversible — confirm with the operator first.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `loser_id` | integer | yes | Absorbed and destroyed |
| `winner_id` | integer | yes | Surviving contact |

### `search_contacts` — read

Search contacts by name, email/phone identity, or social handle/username (Instagram, Telegram, WhatsApp, ...), most recently active first. Omit the query to list recent contacts, or filter them by assignee.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assignee_id` | integer | no | Only records assigned to this person. |
| `limit` | integer | no | Default 20 |
| `query` | string | no | Matches name, any email/phone identity, or platform handle/username |
| `unassigned` | boolean | no | true lists only records with no assignee. |

### `update_contact` — write

Update a contact's CRM fields, including who it is assigned to. Only the provided fields change. stage must be one of the tenant's configured opportunity stages; a valid move is logged and published.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `contact_id` | integer | yes |  |
| `assignee_id` | integer or null | no | Person id from list_assignable_people; null unassigns. |
| `deal_value` | number | no |  |
| `name` | string | no |  |
| `stage` | string | no | One of the tenant's opportunity stages |
| `tags` | array of string | no |  |

### `update_contact_task` — write

Complete or reopen one of a contact's tasks, or hand it to someone.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `contact_id` | integer | yes |  |
| `task_id` | integer | yes |  |
| `assignee_id` | integer or null | no | Person id from list_assignable_people; null unassigns. |
| `operation` | string (`complete` \| `reopen`) | no |  |

### `update_lead_status` — write

Move a lead through its statuses: new, contacted, converted, archived.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `lead_id` | integer | yes |  |
| `status` | string (`new` \| `contacted` \| `converted` \| `archived`) | yes |  |
