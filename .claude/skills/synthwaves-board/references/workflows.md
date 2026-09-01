# Workflows

Multi-step workflow definitions and their runs.

*11 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `create_workflow` — write

Create a workflow (manual trigger unless told otherwise). Changes tenant configuration. Call get_workflow_schema first for the graph format.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assistant_id` | integer | yes | Assistant the workflow runs as |
| `name` | string | yes |  |
| `daily_run_cap` | integer | no |  |
| `daily_token_budget` | integer | no |  |
| `enabled` | boolean | no |  |
| `event_name` | string | no | Required for event triggers; one of the subscribed-event catalog |
| `graph` | object | no | {nodes: [{id, type, config}], edges: [{from, to, branch?}]} — see get_workflow_schema |
| `requires_approval` | boolean | no | Approval-gated tools pause runs for a human |
| `schedule_cron` | string | no | Raw cron expression; the preset fields compile into this |
| `schedule_month_day` | string | no | 1-31, monthly presets only |
| `schedule_preset` | string (`hourly` \| `daily` \| `weekly` \| `monthly` \| `custom`) | no |  |
| `schedule_time` | string | no | HH:MM, used by daily/weekly/monthly presets |
| `schedule_weekday` | string | no | 0-6, weekly presets only |
| `timezone` | string | no | IANA name, e.g. America/New_York |
| `trigger_type` | string (`manual` \| `schedule` \| `event` \| `webhook`) | no |  |

### `delete_workflow` — write, destructive

Delete a workflow. Its runs and their transcripts are deleted with it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `workflow_id` | integer | yes |  |

### `get_workflow` — read

Fetch one workflow's full configuration, including its graph, by id or slug.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `slug` | string | no |  |
| `workflow_id` | integer | no |  |

### `get_workflow_run` — read

Fetch one workflow run with its per-node executions (inputs, outputs, errors, attempts).

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `run_id` | integer | yes |  |
| `workflow_id` | integer | yes |  |

### `get_workflow_schema` — read

Describe the workflow graph format: node types with their required config keys and output keys, condition operators, edge rules, and template tokens, plus a minimal example graph. Read this before writing a graph for create_workflow or update_workflow.

Takes no parameters.

### `list_workflow_runs` — read

List a workflow's runs, newest first. Filter by status. Node-level detail comes from get_workflow_run.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `workflow_id` | integer | yes |  |
| `limit` | integer | no |  |
| `status` | string (`queued` \| `running` \| `waiting` \| `awaiting_approval` \| `succeeded` \| `failed` \| `cancelled` \| `skipped`) | no |  |

### `list_workflows` — read

List the tenant's workflows with their trigger, enabled flag, and run limits. Filter by trigger_type or enabled.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `enabled` | boolean | no |  |
| `limit` | integer | no |  |
| `trigger_type` | string (`manual` \| `schedule` \| `event` \| `webhook`) | no |  |

### `rotate_workflow_webhook_token` — write, destructive

Rotate a workflow's webhook token. WARNING: every previously shared hook URL stops working immediately — callers must update to the returned URL.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `workflow_id` | integer | yes |  |

### `run_workflow` — write

Enqueue a workflow run now. WARNING: this executes the graph for real — agent and tool nodes spend LLM tokens, and nodes like send_message and http_request have live side effects. Daily run/token budgets apply; a capped call returns a skipped run with the reason. Pass idempotency_key so retries return the same run.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `workflow_id` | integer | yes |  |
| `idempotency_key` | string | no | Date-scoped dedupe key; retries return the same run |
| `input` | object | no | Available to nodes as {{input.*}} |

### `update_workflow` — write

Update a workflow. Only the provided fields change; an omitted graph is left untouched. Call get_workflow_schema before authoring a replacement graph.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `workflow_id` | integer | yes |  |
| `assistant_id` | integer | no | Assistant the workflow runs as |
| `daily_run_cap` | integer | no |  |
| `daily_token_budget` | integer | no |  |
| `enabled` | boolean | no |  |
| `event_name` | string | no | Required for event triggers; one of the subscribed-event catalog |
| `graph` | object | no | {nodes: [{id, type, config}], edges: [{from, to, branch?}]} — see get_workflow_schema |
| `name` | string | no |  |
| `requires_approval` | boolean | no | Approval-gated tools pause runs for a human |
| `schedule_cron` | string | no | Raw cron expression; the preset fields compile into this |
| `schedule_month_day` | string | no | 1-31, monthly presets only |
| `schedule_preset` | string (`hourly` \| `daily` \| `weekly` \| `monthly` \| `custom`) | no |  |
| `schedule_time` | string | no | HH:MM, used by daily/weekly/monthly presets |
| `schedule_weekday` | string | no | 0-6, weekly presets only |
| `timezone` | string | no | IANA name, e.g. America/New_York |
| `trigger_type` | string (`manual` \| `schedule` \| `event` \| `webhook`) | no |  |

### `update_workflow_run` — write

Control one workflow run: approve (executes the recorded tool call verbatim — its side effects fire for real), cancel (stops a live run), or replay (enqueues a fresh token-spending run with the same input). WARNING: approve and replay spend resources; confirm with the operator first.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `operation` | string (`approve` \| `cancel` \| `replay`) | yes |  |
| `run_id` | integer | yes |  |
| `workflow_id` | integer | yes |  |
