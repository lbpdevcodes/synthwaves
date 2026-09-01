# Messaging channels

The inbound channels conversations arrive on, and their provisioning.

*8 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `create_channel` — write

Create a messaging channel on an assistant, then best-effort provision it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `adapter` | string (`whatsapp` \| `telegram` \| `gohighlevel` \| `voice` \| `zernio` \| `email`) | yes | widget channels belong to embeds and cannot be created here |
| `assistant_id` | integer | yes | The assistant that answers this channel |
| `name` | string | yes |  |
| `auto_reply` | boolean | no | false keeps the bot silent (listening mode) |
| `clear_credentials` | boolean | no | Drop every stored override |
| `credentials` | object | no | Per-channel overrides for the adapter's declared keys; blank values keep stored secrets. Ignored for adapters the host marks host-managed |
| `enabled` | boolean | no |  |
| `inbound_address` | string | no | Address an email channel receives on |
| `phone_number` | string | no | E.164 number a voice channel answers on |
| `phone_number_id` | string | no | WhatsApp phone number id |
| `realtime_model` | string | no |  |
| `voice` | string | no |  |

### `delete_channel` — write, destructive

Delete a channel. Its conversations and inbound messages go with it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `channel_id` | integer | yes |  |

### `get_channel` — read

Fetch one channel's configuration, webhook URL, and verify token.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `channel_id` | integer | yes |  |

### `list_channels` — read

List the tenant's messaging channels with status and handshake material.

Takes no parameters.

### `provision_channel` — write

Run the channel's platform-side provisioning and report the verdict.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `channel_id` | integer | yes |  |

### `register_channel_webhook` — write

Register this deployment's webhook with the channel's platform (telegram, zernio).

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `channel_id` | integer | yes |  |

### `test_channel` — write

Test a channel's platform connection and report the verdict.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `channel_id` | integer | yes |  |

### `update_channel` — write

Update a channel. Only the provided fields change.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `channel_id` | integer | yes |  |
| `adapter` | string (`whatsapp` \| `telegram` \| `gohighlevel` \| `voice` \| `zernio` \| `email`) | no | widget channels belong to embeds and cannot be created here |
| `assistant_id` | integer | no | The assistant that answers this channel |
| `auto_reply` | boolean | no | false keeps the bot silent (listening mode) |
| `clear_credentials` | boolean | no | Drop every stored override |
| `credentials` | object | no | Per-channel overrides for the adapter's declared keys; blank values keep stored secrets. Ignored for adapters the host marks host-managed |
| `enabled` | boolean | no |  |
| `inbound_address` | string | no | Address an email channel receives on |
| `name` | string | no |  |
| `phone_number` | string | no | E.164 number a voice channel answers on |
| `phone_number_id` | string | no | WhatsApp phone number id |
| `realtime_model` | string | no |  |
| `voice` | string | no |  |
