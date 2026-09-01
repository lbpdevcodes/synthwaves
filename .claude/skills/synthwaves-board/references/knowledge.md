# Knowledge base

The corpus the assistants answer from: collections, connectors that feed them, retrieval, and the gaps a question exposed.

*16 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Back to the [index](00-index.md).

---

### `answer_knowledge_gap` — write

Answer an open knowledge gap by writing a knowledge document. Changes the knowledge base: the document is ingested and becomes searchable, and the gap closes.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `content` | string | yes | Plain-text answer body |
| `gap_id` | integer | yes |  |
| `title` | string | yes |  |
| `collection_ids` | array of integer | no |  |

### `ask` — read

Ask a question answered from the knowledge base by a Synapse assistant. Returns the answer with structured citations. Spends LLM tokens on every call.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `question` | string | yes | The question to answer |
| `assistant_slug` | string | no | Assistant to answer with; omit for the default assistant |
| `collection_ids` | array of integer | no | Narrow retrieval to these knowledge collections; can never widen past the assistant's scope |

### `create_knowledge_collection` — write

Create a knowledge collection. Changes the knowledge base: assistants scoped to the collection retrieve from its documents and connectors.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `color` | string | no |  |
| `description` | string | no |  |
| `icon` | string | no |  |
| `knowledge_connector_ids` | array of integer | no |  |
| `knowledge_document_ids` | array of integer | no |  |

### `create_knowledge_connector` — write

Create a knowledge connector (website_crawler, google_drive, or shopify) and start its first sync. Fill only the fields for the chosen type. Changes the knowledge base: synced documents become searchable by assistants.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `connector_type` | string (`website_crawler` \| `google_drive` \| `shopify`) | yes |  |
| `name` | string | yes |  |
| `folder_id` | string | no | google_drive: folder id |
| `folder_url` | string | no | google_drive: folder URL (id is extracted) |
| `knowledge_collection_ids` | array of integer | no |  |
| `max_pages` | integer | no | website_crawler: page cap (default 25) |
| `recursive` | boolean | no | google_drive: include subfolders (default true) |
| `shop_domain` | string | no | shopify: store domain |
| `shopify_api_version` | string | no | shopify: API version override |
| `shopify_client_id` | string | no | shopify: client id |
| `shopify_client_secret` | string | no | shopify: client secret (write-only) |
| `start_url` | string | no | website_crawler: where to start |

### `delete_knowledge_collection` — write, destructive

Delete a knowledge collection. Its documents and connectors are kept; assistants scoped to it lose that knowledge.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `collection_id` | integer | yes |  |

### `delete_knowledge_connector` — write, destructive

Delete a knowledge connector. Its synced documents are deleted with it and leave the knowledge base.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `connector_id` | integer | yes |  |

### `dismiss_knowledge_gap` — write

Dismiss an open knowledge gap as not worth answering. A recurring question opens a fresh gap later.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `gap_id` | integer | yes |  |

### `get_knowledge_collection` — read

Fetch one knowledge collection by id or slug, with its assignment ids and effective document count.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `collection_id` | integer | no |  |
| `slug` | string | no |  |

### `get_knowledge_connector` — read

Fetch one knowledge connector: settings (secret stripped), sync state, document count, collections.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `connector_id` | integer | yes |  |

### `list_documents` — read

List non-note knowledge-base documents (pasted text, uploads, connector sources), most recent first. Filter by title text or ingest status.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `ingest_status` | string (`pending` \| `processing` \| `ready` \| `failed`) | no |  |
| `limit` | integer | no | Default 50 |
| `q` | string | no | Matches the document title |

### `list_knowledge_collections` — read

List the tenant's knowledge collections with their assignment ids and effective document counts.

Takes no parameters.

### `list_knowledge_connectors` — read

List the tenant's knowledge connectors with their sync state. Shopify secrets never appear — a presence boolean says one is stored.

Takes no parameters.

### `list_knowledge_gaps` — read

List tenant knowledge gaps by status, priority, or recent activity.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `limit` | integer | no | Result limit. Internal default 10. MCP default 50. |
| `order` | string (`priority` \| `recent`) | no | Priority uses occurrence count. Recent uses last activity. |
| `status` | string (`open` \| `answered` \| `dismissed`) | no | Gap status. Default: open. |

### `search_knowledge` — read

Hybrid search over the knowledge base with document context.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `query` | string | yes | The search query |
| `collection_ids` | array of integer | no | Restrict the search to these knowledge collections |
| `limit` | integer | no | Max chunks to return (default 10) |

### `sync_knowledge_connector` — write

Re-sync a knowledge connector now: re-crawls, re-pulls, or re-imports its source. Synced documents become searchable when the job finishes.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `connector_id` | integer | yes |  |

### `update_knowledge_collection` — write

Update a knowledge collection. Only the provided fields change; assignment arrays replace all (unknown ids refuse the whole update).

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `collection_id` | integer | yes |  |
| `color` | string | no |  |
| `description` | string | no |  |
| `icon` | string | no |  |
| `knowledge_connector_ids` | array of integer | no |  |
| `knowledge_document_ids` | array of integer | no |  |
| `name` | string | no |  |
