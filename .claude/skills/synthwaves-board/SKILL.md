---
name: synthwaves-board
description: Operate the Synthwaves account on https://gosynapse.io through its Synapse MCP server — the "Synthwaves" kanban board (project 13, board 15) that runs this project, plus all 148 tools the account key reaches across inbox, knowledge base, notes, contacts, media, assistants, channels, workflows, automations and webhooks. Triggers whenever the user mentions the board, a card, a ticket, the backlog, "what should I work on", or asks to read or change anything in the Synthwaves account. Scoped to this repo only; the fleet-wide synapse-api skill covers the other deployments.
---

# Synthwaves board

This repo builds synthwaves.fm. The team runs the project on a kanban board
inside Synapse, in the account this repo's access key reaches. Use the MCP tools
to read and change that account directly. Do not guess at board state, and do
not ask the user to paste it.

## Account map

| Item | Value |
| --- | --- |
| MCP server | `synapse` → `POST https://gosynapse.io/synapse/mcp` |
| Tool prefix | `mcp__synapse__<tool>` |
| Key | `config/go_synapse_api_key` (gitignored, mode 600) |
| Engine | `synapse 0.1.5` — 148 tools |
| Rate limit | 60 requests per minute |
| Project | **13** — `Synthwaves`, card key prefix `SYN` (the only project) |
| Board | **15** — `Synthwaves` → https://gosynapse.io/synapse/boards/15 |
| Assignee | Leo Policastro is person **1**. He is the only one. |

Columns on board 15, left to right:

| Column | id | Kind | Meaning |
| --- | --- | --- | --- |
| To do | **54** | backlog | Agreed and ready to start. |
| In progress | **55** | active | Being worked on now. |
| Validation | **58** | active | Built, waiting to be proven. |
| Done | **56** | done | Proven. Finished. |

### Type, not a label

A card carries a **kind** of its own. Set it with `card_type` on `create_card`
or `update_card`.

| `card_type` | Use for |
| --- | --- |
| `task` | The default. Work to do. |
| `bug` | Something is broken now. |
| `spike` | Time-boxed investigation. The output is an answer, not a change. |
| `epic` | Too big to start. Split it first. |

`priority` is a separate field: `urgent`, `high`, `medium`, `low`, or unset.
Unset sorts last, so a card only ranks once somebody ranks it. Do not rank a
card by where you drop it.

### Labels

Project 13 has **no labels**. `card_type` and `priority` carry the meaning.
Create a label only when the user asks for one, with
`create_label project_id=13`. Labels are project-scoped, so a new label is
visible on every board in the project.

These ids are pinned for speed. If a call fails on one of them, somebody
renamed or rebuilt the board. Re-read `list_boards project_id=13` and
`list_columns board_id=15`, act on the real ids, then correct these tables.

## Operating rules

Act. Do not ask permission. Reads, `create_*`, `update_*`, `move_*`, comments,
checklist items and labels all go straight through. Report what you changed
afterwards, with card ids.

One exception, and it is a disclosure rule, not a permission request. Before
`delete_project`, `delete_board`, a `delete_column` that still holds cards, or
any `rotate_*` token or secret, first read what will be destroyed. Then act.
Then say exactly what went, in the same message. Deletes cascade to every child
row, and a rotation breaks any live integration that still holds the old
secret.

Never read the access key into a message. Never write a `syn_` string into any
file. Reference it only as `$(cat config/go_synapse_api_key)`.

## Board conventions

- **Search before you open a card.** Run `list_cards board_id=15` and scan the
  titles first. A card may already cover the work.
- **A card id is not a card key.** `move_card`, `update_card` and
  `add_card_comment` all take the numeric `id`. `SYN-1` is the key a human
  reads. `list_cards` returns both.
- **`In progress` holds one card.** Move the current card out before you move
  another in.
- **The card exists before the work does.** No behavior change, fix, feature,
  refactor or production run starts without one.
  [Ticket lifecycle](#ticket-lifecycle) below holds the calls.
- **An approved plan goes in the card description**, word for word, before the
  first edit.
- **Every commit names its card.** Prefix the subject with the card key:
  `SYN-4: Apply loudness gain when the EQ graph is off`. It keeps
  `git log --oneline` scannable card by card. Name the card in the PR title
  too — `main` is branch-protected, so every change lands through a PR.
- Write card descriptions in GitHub-flavored markdown.
- Put `file:line` references, branch names and commit shas in a **comment**, not
  in the title. Titles stay short.

## Traps

Each of these is verified against this live server.

- **Moving a card into Done completes it.** Column 56 has `kind: done`, so
  `move_card` to 56 stamps `completed_at` by itself. Do not also call
  `update_card operation=complete`. Column 58 is `kind: active`, so Validation
  leaves the card open.
- **`list_cards` needs exactly one of `board_id` or `column_id`.** The schema
  marks both optional. The handler rejects both-or-neither with "Pass exactly
  one of board_id or column_id."
- **`update_card` never moves a card between columns.** It has no `column_id`
  parameter. Use `move_card`.
- **`update_card` replaces the whole description.** Send the problem statement
  again above the plan, or you lose it.
- **Positions are 1-based.** `move_card` without `position` drops the card to
  the bottom of the target column.
- **`create_column` cannot place a column.** It appends to the right. Call
  `move_column` afterwards to put it in the right slot.
- **Labels are project-scoped.** `set_card_labels` replaces the whole set; pass
  `[]` to clear it. A label id from another project is rejected.
- **`due_time` requires `due_on`.** An empty string clears a date field.
- **`description_markdown` goes in, `description_html` comes back** from
  `get_card`. There is no markdown round-trip.
- **A private board is invisible over MCP.** The engine resolves boards for an
  access key, which belongs to no person. A missing board is a visibility
  setting, not a broken permission.
- **`destructiveHint` lies on some read tools.** `ask`, `search_knowledge` and
  `list_notes` all report `destructiveHint: true` while also reporting
  `readOnlyHint: true`. Trust `readOnlyHint`, or judge by the verb in the tool
  name.
- **Stay under 60 calls a minute.** Read the whole board with one
  `list_cards board_id=15`, never one call per column. Over the limit the
  server returns JSON-RPC `-32000` and HTTP 429.
- **`gh` talks to the wrong repo by default.** `origin` is
  `git@github.com:pandorocks/synthwaves.git`, which GitHub redirects to
  `lbpdevcodes/synthwaves`. `gh` follows the stale name and acts on the wrong
  repo or reports no PR. Pass `--repo lbpdevcodes/synthwaves` on every `gh pr`
  call, and `--head <branch>` on `gh pr view` and `gh pr checks`.
- **CRM tasks are not kanban cards.** `list_contact_tasks` and friends are
  follow-ups attached to a contact.

## The other 116 tools

The board is 32 of 148 tools. Full parameters for every tool live in
`references/`, generated from the server's own `tools/list`. Open the file you
need; do not guess a schema.

| Module | File | Covers | Tools |
| --- | --- | --- | --- |
| Index | [`references/00-index.md`](references/00-index.md) | Every tool, one line each | 148 |
| Projects | [`references/projects.md`](references/projects.md) | Boards, columns, cards, comments, checklists, labels | 32 |
| Knowledge | [`references/knowledge.md`](references/knowledge.md) | `ask`, search, collections, connectors, knowledge gaps | 16 |
| Integrations | [`references/integrations.md`](references/integrations.md) | Remote tool servers, OAuth connections | 14 |
| Workflows | [`references/workflows.md`](references/workflows.md) | Workflow definitions and runs | 11 |
| Assistants | [`references/assistants.md`](references/assistants.md) | Assistant definitions and skill playbooks | 10 |
| Automations | [`references/automations.md`](references/automations.md) | Trigger-driven automations and runs | 10 |
| CRM | [`references/crm.md`](references/crm.md) | Contacts, opportunities, contact tasks | 9 |
| Media | [`references/media.md`](references/media.md) | Media items and folders | 9 |
| Notes | [`references/notes.md`](references/notes.md) | Notes and note folders | 9 |
| Channels | [`references/channels.md`](references/channels.md) | Messaging channels and provisioning | 8 |
| Webhooks | [`references/webhooks.md`](references/webhooks.md) | Outbound endpoints and deliveries | 8 |
| Inbox | [`references/inbox.md`](references/inbox.md) | Conversations, replies, digest, analytics | 8 |
| Memory | [`references/memory.md`](references/memory.md) | Assistant long-term memory | 4 |

Regenerate the whole catalogue when a call fails on a schema it describes:

```bash
.claude/skills/synthwaves-board/scripts/refresh_catalog
```

It fails loudly when a new tool matches no module, so nothing goes undocumented.

## Ticket lifecycle

Every piece of work in this repo runs through one card.
`.claude/rules/project-management.md` states the rule. This section states the
calls. Keep the card in step with the work: move it when the state changes, not
at the end of the task.

**1. Find the card, or open one.** Search first:

```
list_cards board_id=15
```

Scan the titles. When no card covers the work, open one:

```
create_card column_id=54 title=<short> description_markdown=<problem + acceptance test>
```

**2. Start.** Move the card the moment you read code or write a plan:

```
move_card card_id=<n> column_id=55
```

Move whatever sits in `In progress` out first.

**3. Record the plan.** When the user approves a plan, copy it into the card
before the first edit:

```
update_card card_id=<n> description_markdown=<problem + the approved plan>
```

**4. Report the outcome.** Do this before the card leaves `In progress`:

```
add_card_comment card_id=<n> content_markdown=<commit sha, files touched, what proves it>
```

**5. Land the work.** `main` is branch-protected, so nothing lands by a direct
push. Branch, commit with the card key in the subject, push, open the PR:

```bash
git checkout -b <short-branch-name>
git commit -m "SYN-<n>: <what changed>"
git push -u origin <short-branch-name>
gh pr create --repo lbpdevcodes/synthwaves --head <short-branch-name> \
  --title "SYN-<n>: <what changed>" --body-file <path>
```

Pass `--repo lbpdevcodes/synthwaves --head <branch>` on every `gh pr` call.
See the `gh` trap below for why.

**6. Move to Validation.** The code is complete and the PR is open, but nobody
has merged or proven it:

```
move_card card_id=<n> column_id=58
```

A card waits here while the PR is open. Add the PR URL as a comment.

**7. Close.** The PR is merged *and* the work is proven — a test failed first
and then passed, or a real run showed the behavior:

```
move_card card_id=<n> column_id=56
```

Column 56 completes the card by itself. Do not call
`update_card operation=complete` after it. An unmerged PR is not Done, however
green the tests are.

## Workflows

**Report the board.** One call: `list_cards board_id=15`. Group the result by
`column_id` and name the columns from the table above. Do not call per column.

**Pick the next card.** `list_cards column_id=54`, then rank by `priority`,
`due_on` and `card_type`. An `epic` is never next; split it first.

**File a card from the inbox.** `list_conversations` → `get_conversation` →
`create_card` in `To do` naming the conversation id in the description →
`create_conversation_note` on the conversation pointing back at the card id.

**Close a knowledge gap.** `list_knowledge_gaps` → `answer_knowledge_gap` when
you know the answer, `dismiss_knowledge_gap` when the question is out of scope.

**A new board for another purpose.** `create_board project_id=13 name=<name>`,
then `create_column` for each column, left to right, then `move_column` to fix
the order. This skill needs no change.

## When the MCP server is not connected

The tools appear only after Claude Code connects the server at startup. If
`mcp__synapse__*` tools are missing, re-register and restart:

```bash
claude mcp remove synapse -s local
claude mcp add --transport http synapse https://gosynapse.io/synapse/mcp \
  -H "Authorization: Bearer $(tr -d '\n' < config/go_synapse_api_key)"
```

Until the restart, call the same tools over raw JSON-RPC. Cloudflare fronts this
host and blocks unusual user agents with a 1010, so use `curl`:

```bash
curl -sS -X POST https://gosynapse.io/synapse/mcp \
  -H "Authorization: Bearer $(tr -d '\n' < config/go_synapse_api_key)" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call",
       "params":{"name":"list_cards","arguments":{"board_id":15}}}'
```

The result arrives as JSON text at `.result.content[0].text`. A failed call
returns `isError: true` with the reason in the same field. A dead or revoked key
returns HTTP 401 with `-32001`; mint a new one at
https://gosynapse.io/synapse/admin/access_keys and write it to
`config/go_synapse_api_key`.
