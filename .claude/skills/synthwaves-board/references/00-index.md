# Synapse MCP tool index

*148 tools. Generated from `tools/list` on synapse 0.1.5. Regenerate with `.claude/skills/synthwaves-board/scripts/refresh_catalog` — do not edit by hand.*

Every tool the synthwaves account key can call, grouped by module. Open the module file for full parameters.

## Projects, boards, columns and cards — [`projects.md`](projects.md) (32)

- `add_card_comment` — Add a markdown comment to a card.
- `create_board` — Create a board in a project. New boards land last; follow with create_column to set up its columns.
- `create_card` — Create a card in a column, optionally assigned to someone.
- `create_checklist_item` — Add a checklist item to a card. New items land at the bottom.
- `create_column` — Create a column on a board. New columns land rightmost and are active unless a kind is given.
- `create_label` — Create a label in a project (name plus hex color, e.g. #ef4444).
- `create_project` — Create a project (a group of kanban boards).
- `delete_board` — Delete a board. Its columns and cards are deleted with it.
- `delete_card` — Delete a card. Its comments and checklist items are deleted with it.
- `delete_card_comment` — Delete a card comment.
- `delete_checklist_item` — Delete a card checklist item.
- `delete_column` — Delete a column. Its cards are deleted with it — move them first with move_card to keep them.
- `delete_label` — Delete a project label and remove it from every card.
- `delete_project` — Delete a project. Its boards, columns, and cards are deleted with it.
- `get_card` — Get a card with its description, labels, checklist items, and comments.
- `list_assignable_people` — List the teammates a card, board, project, contact, task, or conversation can be assigned to. Returns each person's id and name; pass that id as assignee_id when you assign something. Scoped to this tenant's own people.
- `list_boards` — List a project's boards in display order.
- `list_card_comments` — List a card's comments, oldest first.
- `list_cards` — List cards on a board or in one column, optionally only the ones a person holds or that nobody holds.
- `list_columns` — List a board's columns in display order.
- `list_labels` — List a project's labels. Labels are project-scoped: one palette serves all of its boards.
- `list_projects` — List projects and their boards.
- `move_card` — Move a card to a column.
- `move_column` — Move a column to a one-based position on its board.
- `set_card_labels` — Replace a card's labels with the given label ids (from the card's project). Pass [] to clear.
- `update_board` — Rename a board, or assign it to someone.
- `update_card` — Update a card's title, description, due date, or assignee, or complete/reopen it via operation.
- `update_card_comment` — Update a card comment from markdown.
- `update_checklist_item` — Rename a card's checklist item, or complete/reopen it via operation.
- `update_column` — Rename a column, or set what it means: backlog, active or done.
- `update_label` — Update a project label's name, color, or both.
- `update_project` — Rename a project, or assign it to someone.

## Assistant memory — [`memory.md`](memory.md) (4)

- `delete_assistant_memory` — Delete one assistant memory document. The assistant forgets the fact.
- `list_assistant_memories` — List assistant memory documents (facts an assistant stored), newest first, with content. Filter by assistant_id.
- `memory_search` — Search your own saved long-term memories about this user or context. Use this to recall facts you previously stored with memory_write.
- `memory_write` — Save or update a durable memory about this user or context so you can recall it in future conversations. Reuse the same `key` to UPDATE an existing memory instead of creating a duplicate. Store only durable, reusable facts (preferences, stable context, decisions) — not transient details, secrets, or credentials.

## Inbox conversations — [`inbox.md`](inbox.md) (8)

- `assign_conversation` — Assign an inbox conversation to a teammate, or pass a null assignee_id to unassign it.
- `conversation_analytics` — Conversation-quality metrics over a time range: totals, escalation/resolution/deflection rates, median first response, volume by platform, busiest hours, top ticket categories.
- `create_conversation_note` — Add an internal staff note to a conversation from markdown. The note is never shown to the customer, never delivered to the channel, and never read by the assistant.
- `get_conversation` — Show one conversation with its trailing message transcript (user and assistant messages only).
- `inbox_digest` — Returns a compact digest of inbox conversation activity: totals, escalations, resolutions, and one line per recent conversation (contact, channel, preview, status). Use it to summarize what happened in the inbox over a period, or to find conversations that have gone quiet.
- `list_conversations` — List messaging-channel conversations (the team inbox), most recent first. Filter by status, free text (contact name or external id), assignee, or unread only.
- `reply_to_conversation` — Send a human reply into a conversation. WARNING: this messages the real customer through the channel and pauses the bot. Confirm with the operator before sending.
- `update_conversation_status` — Change a conversation's bot state: pause (a human takes over, bot goes quiet), resolve (bot resumes), or restart (roll over to a fresh chat session; returns the new chat_id).

## Knowledge base — [`knowledge.md`](knowledge.md) (16)

- `answer_knowledge_gap` — Answer an open knowledge gap by writing a knowledge document. Changes the knowledge base: the document is ingested and becomes searchable, and the gap closes.
- `ask` — Ask a question answered from the knowledge base by a Synapse assistant. Returns the answer with structured citations. Spends LLM tokens on every call.
- `create_knowledge_collection` — Create a knowledge collection. Changes the knowledge base: assistants scoped to the collection retrieve from its documents and connectors.
- `create_knowledge_connector` — Create a knowledge connector (website_crawler, google_drive, or shopify) and start its first sync. Fill only the fields for the chosen type. Changes the knowledge base: synced documents become searchable by assistants.
- `delete_knowledge_collection` — Delete a knowledge collection. Its documents and connectors are kept; assistants scoped to it lose that knowledge.
- `delete_knowledge_connector` — Delete a knowledge connector. Its synced documents are deleted with it and leave the knowledge base.
- `dismiss_knowledge_gap` — Dismiss an open knowledge gap as not worth answering. A recurring question opens a fresh gap later.
- `get_knowledge_collection` — Fetch one knowledge collection by id or slug, with its assignment ids and effective document count.
- `get_knowledge_connector` — Fetch one knowledge connector: settings (secret stripped), sync state, document count, collections.
- `list_documents` — List non-note knowledge-base documents (pasted text, uploads, connector sources), most recent first. Filter by title text or ingest status.
- `list_knowledge_collections` — List the tenant's knowledge collections with their assignment ids and effective document counts.
- `list_knowledge_connectors` — List the tenant's knowledge connectors with their sync state. Shopify secrets never appear — a presence boolean says one is stored.
- `list_knowledge_gaps` — List tenant knowledge gaps by status, priority, or recent activity.
- `search_knowledge` — Hybrid search over the knowledge base with document context.
- `sync_knowledge_connector` — Re-sync a knowledge connector now: re-crawls, re-pulls, or re-imports its source. Synced documents become searchable when the job finishes.
- `update_knowledge_collection` — Update a knowledge collection. Only the provided fields change; assignment arrays replace all (unknown ids refuse the whole update).

## Notes — [`notes.md`](notes.md) (9)

- `create_note` — Create and ingest a knowledge-base note from markdown. Blocks: "> [!INFO\|WARN\|SUCCESS]" quotes render as callouts and "> [!TOGGLE] Summary" quotes as collapsible toggles. For a daily note, file it in the "Daily Notes" folder with the date (YYYY-MM-DD) as the title.
- `create_note_folder` — Create a note folder. Omit parent_id for a root folder; an unknown parent id is rejected.
- `delete_note` — Move a knowledge-base note to the trash. Its search chunks are removed immediately; restore_note can bring it back within 30 days.
- `get_note` — Read one knowledge-base note: markdown content, canonical HTML, and its resolved wikilinks and backlinks.
- `list_note_folders` — List note folders as a flat list, ordered by name. parent_id encodes the tree; null means a root folder.
- `list_notes` — List knowledge-base notes, ordered by title. Metadata only — call get_note with a note id to read its content.
- `restore_note` — Restore a note from the trash. It becomes searchable again and open [[wikilinks]] to its title re-adopt it.
- `update_note` — Update a knowledge-base note. Only the provided fields change: title, content_markdown (re-rendered to HTML and re-ingested; "> [!INFO\|WARN\|SUCCESS]" quotes render as callouts, "> [!TOGGLE] Summary" as collapsible toggles), note_folder_id (null moves to root), collection_ids (replaces all).
- `update_note_folder` — Rename a note folder or move it within the tree. Only the provided fields change; a null parent_id moves the folder to root. An unknown parent id is rejected.

## Contacts and opportunities — [`crm.md`](crm.md) (9)

- `capture_opportunity` — Captures a new sales opportunity: finds or creates the CRM contact by email and records their inquiry as an internal note. Use for inbound leads from forms and workflows.
- `create_contact` — Create a CRM contact. identities is a list of {kind, value} with kind email, phone, or handle ("platform:id"); values normalize (case-folded emails, digit-only phones).
- `create_contact_task` — Create a follow-up task on a contact ("call back Tuesday"), optionally with a due date.
- `list_contact_tasks` — List a contact's follow-up tasks. status open (default), completed, or all.
- `merge_contacts` — Merge loser into winner: the loser's identities, chats, conversations, and leads move to the winner, then the loser is destroyed. WARNING: irreversible — confirm with the operator first.
- `search_contacts` — Search contacts by name, email/phone identity, or social handle/username (Instagram, Telegram, WhatsApp, ...), most recently active first. Omit the query to list recent contacts, or filter them by assignee.
- `update_contact` — Update a contact's CRM fields, including who it is assigned to. Only the provided fields change. stage must be one of the tenant's configured opportunity stages; a valid move is logged and published.
- `update_contact_task` — Complete or reopen one of a contact's tasks, or hand it to someone.
- `update_lead_status` — Move a lead through its statuses: new, contacted, converted, archived.

## Media storage — [`media.md`](media.md) (9)

- `create_media_folder` — Create a media-library folder. Omit parent_id for a root folder; an unknown parent id is rejected.
- `create_media_item` — Add a file to the media library. Give either url (an https address to download) or data (base64 contents, which also needs filename). Images, documents and code files up to 10 MB; audio and video up to 50 MB.
- `delete_media_folder` — Delete a media-library folder. Its files and sub-folders move up one level, never deleted.
- `delete_media_item` — Delete a file from the media library. The stored file is kept only if a chat message or another record still uses it.
- `get_media_item` — Read one media-library file: filename, type, size, source, folder and a fetchable URL.
- `list_media` — List files in the media library, newest first. Filter by kind, source, folder, or a filename search. Returns metadata and a fetchable URL per file. Images generated in chat and files sent or received in conversations are saved here automatically — look here before asking anyone to re-upload something.
- `list_media_folders` — List the media library's folders by name. parent_id encodes the tree.
- `update_media_folder` — Rename a media-library folder, move it under another parent, or both. parent_id null moves it to the root.
- `update_media_item` — Move a media-library file to another folder. Pass folder_id, or null for the library root.

## Messaging channels — [`channels.md`](channels.md) (8)

- `create_channel` — Create a messaging channel on an assistant, then best-effort provision it.
- `delete_channel` — Delete a channel. Its conversations and inbound messages go with it.
- `get_channel` — Fetch one channel's configuration, webhook URL, and verify token.
- `list_channels` — List the tenant's messaging channels with status and handshake material.
- `provision_channel` — Run the channel's platform-side provisioning and report the verdict.
- `register_channel_webhook` — Register this deployment's webhook with the channel's platform (telegram, zernio).
- `test_channel` — Test a channel's platform connection and report the verdict.
- `update_channel` — Update a channel. Only the provided fields change.

## Workflows — [`workflows.md`](workflows.md) (11)

- `create_workflow` — Create a workflow (manual trigger unless told otherwise). Changes tenant configuration. Call get_workflow_schema first for the graph format.
- `delete_workflow` — Delete a workflow. Its runs and their transcripts are deleted with it.
- `get_workflow` — Fetch one workflow's full configuration, including its graph, by id or slug.
- `get_workflow_run` — Fetch one workflow run with its per-node executions (inputs, outputs, errors, attempts).
- `get_workflow_schema` — Describe the workflow graph format: node types with their required config keys and output keys, condition operators, edge rules, and template tokens, plus a minimal example graph. Read this before writing a graph for create_workflow or update_workflow.
- `list_workflow_runs` — List a workflow's runs, newest first. Filter by status. Node-level detail comes from get_workflow_run.
- `list_workflows` — List the tenant's workflows with their trigger, enabled flag, and run limits. Filter by trigger_type or enabled.
- `rotate_workflow_webhook_token` — Rotate a workflow's webhook token. WARNING: every previously shared hook URL stops working immediately — callers must update to the returned URL.
- `run_workflow` — Enqueue a workflow run now. WARNING: this executes the graph for real — agent and tool nodes spend LLM tokens, and nodes like send_message and http_request have live side effects. Daily run/token budgets apply; a capped call returns a skipped run with the reason. Pass idempotency_key so retries return the same run.
- `update_workflow` — Update a workflow. Only the provided fields change; an omitted graph is left untouched. Call get_workflow_schema before authoring a replacement graph.
- `update_workflow_run` — Control one workflow run: approve (executes the recorded tool call verbatim — its side effects fire for real), cancel (stops a live run), or replay (enqueues a fresh token-spending run with the same input). WARNING: approve and replay spend resources; confirm with the operator first.

## Automations — [`automations.md`](automations.md) (10)

- `create_automation` — Create an automation (manual trigger unless told otherwise). Changes tenant configuration.
- `delete_automation` — Delete an automation. Its runs and their transcripts are deleted with it.
- `get_automation` — Fetch one automation's full configuration, including its prompt template, by id or slug.
- `get_automation_run` — Fetch one automation run: status, input, output, error, pending approval, and its event log.
- `list_automation_runs` — List an automation's runs, newest first. Filter by status.
- `list_automations` — List the tenant's automations with their trigger, enabled flag, and run limits. Filter by trigger_type or enabled.
- `rotate_automation_webhook_token` — Rotate an automation's webhook token. WARNING: every previously shared hook URL stops working immediately — callers must update to the returned URL.
- `run_automation` — Enqueue an automation run now. WARNING: this runs the assistant for real — it spends LLM tokens and its tools may have live side effects. Daily run/token budgets apply; a capped call returns a skipped run with the reason. Pass idempotency_key so retries return the same run.
- `update_automation` — Update an automation. Only the provided fields change.
- `update_automation_run` — Control one automation run: approve (executes the recorded tool call verbatim — its side effects fire for real), cancel (stops a live run), or replay (enqueues a fresh token-spending run with the same input). WARNING: approve and replay spend resources; confirm with the operator first.

## Tool servers and connections — [`integrations.md`](integrations.md) (14)

- `create_connection` — Connect a key-auth provider by storing its credential. OAuth providers need the browser flow under Admin → Connections.
- `create_tool_server` — Register an external MCP tool server for the tenant.
- `delete_connection` — Disconnect a provider and delete its stored credential.
- `delete_tool_server` — Delete an MCP tool server and its imported tools.
- `get_tool_server` — Fetch one MCP tool server and its imported tools.
- `list_connections` — List provider connections: what can connect, what is connected, and how.
- `list_tool_server_tools` — List one MCP server's imported tools and their curation state.
- `list_tool_servers` — List the tenant's MCP tool servers with auth status and tool counts.
- `list_tools` — List the calling assistant's own tools, with descriptions and risk flags. Pass scope=grantable for every tool this tenant may grant to an assistant.
- `refresh_tool_server_tools` — Import the tools an MCP server advertises. New tools arrive disabled until curated.
- `setup_tool_server` — Register an MCP tool server, test the connection, and import its tools in one call.
- `test_tool_server` — Ping an MCP tool server and report whether it answers.
- `update_tool_server` — Update an MCP tool server. Only the provided fields change; blank secrets keep stored values.
- `update_tool_server_tool` — Enable or disable one imported MCP tool, or change its side_effect flag.

## Assistants and skills — [`assistants.md`](assistants.md) (10)

- `create_assistant` — Create an assistant (draft unless a status is given). Changes tenant configuration.
- `create_skill` — Create a skill: a playbook agents load on demand through use_skill. Changes tenant configuration.
- `delete_assistant` — Delete an assistant. Fails when channels, automations, or workflows still reference it.
- `delete_skill` — Delete a tenant skill. Built-in skills cannot be deleted; hide one with update_skill enabled: false.
- `get_assistant` — Fetch one assistant's full configuration by id or slug.
- `get_skill` — Read one skill, including its full markdown instructions.
- `list_assistants` — List the tenant's assistants and their configuration.
- `list_skills` — List the tenant's skill catalogue: built-in and tenant skills with descriptions and granted tools. Metadata only — call get_skill with a slug to read instructions.
- `update_assistant` — Update an assistant. Only the provided fields change; set status to published or hidden to change visibility.
- `update_skill` — Update a skill. Only the provided fields change. Updating a built-in creates this tenant's editable copy of it.

## Webhook endpoints — [`webhooks.md`](webhooks.md) (8)

- `create_webhook_endpoint` — Create an outbound webhook endpoint. The response includes the full signing secret exactly once — store it; later responses show only its prefix.
- `delete_webhook_endpoint` — Delete an outbound webhook endpoint. Its delivery log is deleted with it and events stop flowing immediately.
- `get_webhook_endpoint` — Fetch one outbound webhook endpoint. The signing secret never appears — only its prefix.
- `list_webhook_deliveries` — List an endpoint's delivery attempts, newest first. Filter by status.
- `list_webhook_endpoints` — List the tenant's outbound webhook endpoints with their subscriptions and circuit-breaker state.
- `rotate_webhook_endpoint_secret` — Rotate an endpoint's signing secret. WARNING: signatures change immediately — receivers must update to the returned secret. Shown in full only in this response.
- `test_webhook_endpoint` — Send a signed ping event to the endpoint through the real delivery pipeline. WARNING: this fires a live HTTP request to the endpoint URL.
- `update_webhook_endpoint` — Update an outbound webhook endpoint. Only the provided fields change; re-activating a disabled endpoint resets its failure streak.
