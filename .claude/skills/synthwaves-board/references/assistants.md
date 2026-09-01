# Assistants and skills

The assistant definitions and the on-demand skill playbooks they load.

*10 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `create_assistant` — write

Create an assistant (draft unless a status is given). Changes tenant configuration.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `model_id` | integer | yes | Model id from list_assistants model refs |
| `name` | string | yes |  |
| `avatar_icon` | string | no | One display glyph, e.g. a single emoji |
| `default` | boolean | no | Preselect this assistant for new chats |
| `description` | string | no |  |
| `instructions_template` | string | no | The system-prompt template |
| `knowledge_collection_ids` | array of integer | no |  |
| `knowledge_scope` | string (`none` \| `selected` \| `all` \| `notes`) | no |  |
| `model_params` | object | no | temperature, max_tokens, top_p, frequency_penalty, presence_penalty |
| `skill_slugs` | array of string | no | Skills the assistant may load on demand, from list_skills |
| `slug` | string | no | kebab-case; derived from the name when omitted |
| `starter_prompts` | array of string | no |  |
| `status` | string (`draft` \| `published` \| `hidden`) | no | published makes the assistant live |
| `tool_slugs` | array of string | no | Grantable slugs from list_tools(scope: grantable) |

### `create_skill` — write

Create a skill: a playbook agents load on demand through use_skill. Changes tenant configuration.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `description` | string | yes | One line the agent always sees in its skill index; say when to load the skill |
| `instructions` | string | yes | Markdown the agent reads when it loads the skill |
| `name` | string | yes |  |
| `enabled` | boolean | no | false removes the skill from the catalogue |
| `slug` | string | no | kebab-case; derived from the name when omitted. Reusing a built-in's slug replaces that built-in for this tenant |
| `tool_slugs` | array of string | no | Tools switched on for the conversation when the skill loads |

### `delete_assistant` — write, destructive

Delete an assistant. Fails when channels, automations, or workflows still reference it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assistant_id` | integer | yes |  |

### `delete_skill` — write, destructive

Delete a tenant skill. Built-in skills cannot be deleted; hide one with update_skill enabled: false.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `slug` | string | yes |  |

### `get_assistant` — read

Fetch one assistant's full configuration by id or slug.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assistant_id` | integer | no |  |
| `slug` | string | no |  |

### `get_skill` — read

Read one skill, including its full markdown instructions.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `slug` | string | yes | Skill slug from list_skills |

### `list_assistants` — read

List the tenant's assistants and their configuration.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `limit` | integer | no |  |
| `q` | string | no | Case-insensitive name filter |
| `status` | string (`draft` \| `published` \| `hidden`) | no |  |

### `list_skills` — read

List the tenant's skill catalogue: built-in and tenant skills with descriptions and granted tools. Metadata only — call get_skill with a slug to read instructions.

Takes no parameters.

### `update_assistant` — write

Update an assistant. Only the provided fields change; set status to published or hidden to change visibility.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `assistant_id` | integer | yes |  |
| `avatar_icon` | string | no | One display glyph, e.g. a single emoji |
| `default` | boolean | no | Preselect this assistant for new chats |
| `description` | string | no |  |
| `instructions_template` | string | no | The system-prompt template |
| `knowledge_collection_ids` | array of integer | no |  |
| `knowledge_scope` | string (`none` \| `selected` \| `all` \| `notes`) | no |  |
| `model_id` | integer | no | Model id from list_assistants model refs |
| `model_params` | object | no | temperature, max_tokens, top_p, frequency_penalty, presence_penalty |
| `name` | string | no |  |
| `skill_slugs` | array of string | no | Skills the assistant may load on demand, from list_skills |
| `slug` | string | no | kebab-case; derived from the name when omitted |
| `starter_prompts` | array of string | no |  |
| `status` | string (`draft` \| `published` \| `hidden`) | no | published makes the assistant live |
| `tool_slugs` | array of string | no | Grantable slugs from list_tools(scope: grantable) |

### `update_skill` — write

Update a skill. Only the provided fields change. Updating a built-in creates this tenant's editable copy of it.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `slug` | string | yes |  |
| `description` | string | no | One line the agent always sees in its skill index; say when to load the skill |
| `enabled` | boolean | no | false removes the skill from the catalogue |
| `instructions` | string | no | Markdown the agent reads when it loads the skill |
| `name` | string | no |  |
| `tool_slugs` | array of string | no | Tools switched on for the conversation when the skill loads |
