# Webhook endpoints

Outbound webhook endpoints and their delivery log.

*8 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `create_webhook_endpoint` — write

Create an outbound webhook endpoint. The response includes the full signing secret exactly once — store it; later responses show only its prefix.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `subscribed_events` | array of string | yes |  |
| `url` | string | yes | http(s) destination for signed event payloads |
| `active` | boolean | no |  |
| `name` | string | no |  |

### `delete_webhook_endpoint` — write, destructive

Delete an outbound webhook endpoint. Its delivery log is deleted with it and events stop flowing immediately.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `endpoint_id` | integer | yes |  |

### `get_webhook_endpoint` — read

Fetch one outbound webhook endpoint. The signing secret never appears — only its prefix.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `endpoint_id` | integer | yes |  |

### `list_webhook_deliveries` — read

List an endpoint's delivery attempts, newest first. Filter by status.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `endpoint_id` | integer | yes |  |
| `limit` | integer | no |  |
| `status` | string (`pending` \| `delivered` \| `failed`) | no |  |

### `list_webhook_endpoints` — read

List the tenant's outbound webhook endpoints with their subscriptions and circuit-breaker state.

Takes no parameters.

### `rotate_webhook_endpoint_secret` — write, destructive

Rotate an endpoint's signing secret. WARNING: signatures change immediately — receivers must update to the returned secret. Shown in full only in this response.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `endpoint_id` | integer | yes |  |

### `test_webhook_endpoint` — write

Send a signed ping event to the endpoint through the real delivery pipeline. WARNING: this fires a live HTTP request to the endpoint URL.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `endpoint_id` | integer | yes |  |

### `update_webhook_endpoint` — write

Update an outbound webhook endpoint. Only the provided fields change; re-activating a disabled endpoint resets its failure streak.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `endpoint_id` | integer | yes |  |
| `active` | boolean | no |  |
| `name` | string | no |  |
| `subscribed_events` | array of string | no |  |
| `url` | string | no | http(s) destination for signed event payloads |
