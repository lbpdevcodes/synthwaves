# Automations

Trigger-driven automations and their runs.

*10 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `create_automation` — write

Create an automation (manual trigger unless told otherwise). Changes tenant configuration.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assistant_id` | integer | yes | Assistant the automation runs as |
| `name` | string | yes |  |
| `prompt_template` | string | yes | Supports {{input.<path>}}, {{current_date}}, {{current_time}} |
| `daily_run_cap` | integer | no |  |
| `daily_token_budget` | integer | no |  |
| `enabled` | boolean | no |  |
| `event_name` | string | no | Required for event triggers; one of the subscribed-event catalog |
| `requires_approval` | boolean | no | Approval-gated tools pause runs for a human |
| `schedule_cron` | string | no | Raw cron expression; the preset fields compile into this |
| `schedule_month_day` | string | no | 1-31, monthly presets only |
| `schedule_preset` | string (`hourly` \| `daily` \| `weekly` \| `monthly` \| `custom`) | no |  |
| `schedule_time` | string | no | HH:MM, used by daily/weekly/monthly presets |
| `schedule_weekday` | string | no | 0-6, weekly presets only |
| `timezone` | string | no | IANA name, e.g. America/New_York |
| `tool_slugs` | array of string | no | Restricts the assistant's tools; omit for all of them |
| `trigger_type` | string (`manual` \| `schedule` \| `event` \| `webhook`) | no |  |

### `delete_automation` — write, destructive

Delete an automation. Its runs and their transcripts are deleted with it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `automation_id` | integer | yes |  |

### `get_automation` — read

Fetch one automation's full configuration, including its prompt template, by id or slug.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `automation_id` | integer | no |  |
| `slug` | string | no |  |

### `get_automation_run` — read

Fetch one automation run: status, input, output, error, pending approval, and its event log.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `automation_id` | integer | yes |  |
| `run_id` | integer | yes |  |

### `list_automation_runs` — read

List an automation's runs, newest first. Filter by status.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `automation_id` | integer | yes |  |
| `limit` | integer | no |  |
| `status` | string (`queued` \| `running` \| `awaiting_approval` \| `succeeded` \| `failed` \| `cancelled` \| `skipped`) | no |  |

### `list_automations` — read

List the tenant's automations with their trigger, enabled flag, and run limits. Filter by trigger_type or enabled.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `enabled` | boolean | no |  |
| `limit` | integer | no |  |
| `trigger_type` | string (`manual` \| `schedule` \| `event` \| `webhook`) | no |  |

### `rotate_automation_webhook_token` — write, destructive

Rotate an automation's webhook token. WARNING: every previously shared hook URL stops working immediately — callers must update to the returned URL.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `automation_id` | integer | yes |  |

### `run_automation` — write

Enqueue an automation run now. WARNING: this runs the assistant for real — it spends LLM tokens and its tools may have live side effects. Daily run/token budgets apply; a capped call returns a skipped run with the reason. Pass idempotency_key so retries return the same run.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `automation_id` | integer | yes |  |
| `idempotency_key` | string | no | Date-scoped dedupe key; retries return the same run |
| `input` | object | no | Available to the prompt as {{input.*}} |

### `update_automation` — write

Update an automation. Only the provided fields change.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `automation_id` | integer | yes |  |
| `assistant_id` | integer | no | Assistant the automation runs as |
| `daily_run_cap` | integer | no |  |
| `daily_token_budget` | integer | no |  |
| `enabled` | boolean | no |  |
| `event_name` | string | no | Required for event triggers; one of the subscribed-event catalog |
| `name` | string | no |  |
| `prompt_template` | string | no | Supports {{input.<path>}}, {{current_date}}, {{current_time}} |
| `requires_approval` | boolean | no | Approval-gated tools pause runs for a human |
| `schedule_cron` | string | no | Raw cron expression; the preset fields compile into this |
| `schedule_month_day` | string | no | 1-31, monthly presets only |
| `schedule_preset` | string (`hourly` \| `daily` \| `weekly` \| `monthly` \| `custom`) | no |  |
| `schedule_time` | string | no | HH:MM, used by daily/weekly/monthly presets |
| `schedule_weekday` | string | no | 0-6, weekly presets only |
| `timezone` | string | no | IANA name, e.g. America/New_York |
| `tool_slugs` | array of string | no | Restricts the assistant's tools; omit for all of them |
| `trigger_type` | string (`manual` \| `schedule` \| `event` \| `webhook`) | no |  |

### `update_automation_run` — write

Control one automation run: approve (executes the recorded tool call verbatim — its side effects fire for real), cancel (stops a live run), or replay (enqueues a fresh token-spending run with the same input). WARNING: approve and replay spend resources; confirm with the operator first.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `automation_id` | integer | yes |  |
| `operation` | string (`approve` \| `cancel` \| `replay`) | yes |  |
| `run_id` | integer | yes |  |
