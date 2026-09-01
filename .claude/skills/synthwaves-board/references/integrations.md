# Tool servers and connections

Remote MCP tool servers this deployment consumes, and OAuth connections.

*14 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `create_connection` — write

Connect a key-auth provider by storing its credential. OAuth providers need the browser flow under Admin → Connections.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `credentials` | object | yes | The provider's declared credential fields, e.g. {bot_token} |
| `provider` | string | yes | Provider slug from list_connections |

### `create_tool_server` — write

Register an external MCP tool server for the tenant.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `slug` | string | yes | kebab-case, max 20 chars; prefixes every tool name |
| `url` | string | yes | The server's MCP endpoint URL |
| `active` | boolean | no |  |
| `auth_header` | string | no | Header name; defaults to Authorization |
| `auth_mode` | string (`header` \| `connection` \| `oauth`) | no | header pastes a static secret; connection reuses a provider connection; oauth runs a browser flow |
| `auth_value` | string | no | The secret. A bare token under Authorization gets a Bearer prefix. Blank keeps the stored value. |
| `connection_provider` | string | no | Provider slug for connection auth mode |
| `oauth_client_id` | string | no | Pre-registered OAuth client; blank string removes it |
| `oauth_client_secret` | string | no | Blank keeps the stored secret |

### `delete_connection` — write, destructive

Disconnect a provider and delete its stored credential.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `provider` | string | yes |  |

### `delete_tool_server` — write, destructive

Delete an MCP tool server and its imported tools.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `tool_server_id` | integer | yes |  |

### `get_tool_server` — read

Fetch one MCP tool server and its imported tools.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `tool_server_id` | integer | yes |  |

### `list_connections` — read

List provider connections: what can connect, what is connected, and how.

Takes no parameters.

### `list_tool_server_tools` — read

List one MCP server's imported tools and their curation state.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `tool_server_id` | integer | yes |  |

### `list_tool_servers` — read

List the tenant's MCP tool servers with auth status and tool counts.

Takes no parameters.

### `list_tools` — read

List the calling assistant's own tools, with descriptions and risk flags. Pass scope=grantable for every tool this tenant may grant to an assistant.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `scope` | string (`mine` \| `grantable`) | no | mine: the caller's own granted tools. grantable: the whole tenant catalog. |

### `refresh_tool_server_tools` — write

Import the tools an MCP server advertises. New tools arrive disabled until curated.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `tool_server_id` | integer | yes |  |

### `setup_tool_server` — write

Register an MCP tool server, test the connection, and import its tools in one call.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `slug` | string | yes | kebab-case, max 20 chars; prefixes every tool name |
| `url` | string | yes | The server's MCP endpoint URL |
| `active` | boolean | no |  |
| `auth_header` | string | no | Header name; defaults to Authorization |
| `auth_mode` | string (`header` \| `connection` \| `oauth`) | no | header pastes a static secret; connection reuses a provider connection; oauth runs a browser flow |
| `auth_value` | string | no | The secret. A bare token under Authorization gets a Bearer prefix. Blank keeps the stored value. |
| `connection_provider` | string | no | Provider slug for connection auth mode |
| `oauth_client_id` | string | no | Pre-registered OAuth client; blank string removes it |
| `oauth_client_secret` | string | no | Blank keeps the stored secret |

### `test_tool_server` — write

Ping an MCP tool server and report whether it answers.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `tool_server_id` | integer | yes |  |

### `update_tool_server` — write

Update an MCP tool server. Only the provided fields change; blank secrets keep stored values.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `tool_server_id` | integer | yes |  |
| `active` | boolean | no |  |
| `auth_header` | string | no | Header name; defaults to Authorization |
| `auth_mode` | string (`header` \| `connection` \| `oauth`) | no | header pastes a static secret; connection reuses a provider connection; oauth runs a browser flow |
| `auth_value` | string | no | The secret. A bare token under Authorization gets a Bearer prefix. Blank keeps the stored value. |
| `connection_provider` | string | no | Provider slug for connection auth mode |
| `name` | string | no |  |
| `oauth_client_id` | string | no | Pre-registered OAuth client; blank string removes it |
| `oauth_client_secret` | string | no | Blank keeps the stored secret |
| `slug` | string | no | kebab-case, max 20 chars; prefixes every tool name |
| `url` | string | no | The server's MCP endpoint URL |

### `update_tool_server_tool` — write

Enable or disable one imported MCP tool, or change its side_effect flag.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `tool_id` | integer | yes |  |
| `tool_server_id` | integer | yes |  |
| `enabled` | boolean | no |  |
| `side_effect` | boolean | no | Side-effecting tools are approval-gated in unattended runs |
