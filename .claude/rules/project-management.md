# Project Management

Every piece of work in this repo runs through a card on the Synthwaves kanban
board: project 13, board 15, at https://gosynapse.io/synapse/boards/15.
The `synthwaves-board` skill holds the column ids, the tool calls and the traps.
Read that skill before you touch the board.

## The rule

1. **No work without a card.** A behavior change, a fix, a feature, a refactor
   or a production run needs a card.
2. **An unticketed request opens the card first.** When the user asks for a
   change that no card covers, open the card before you read code, write a plan
   or edit a file. Search the board first. A card may already exist.
3. **The plan belongs in the card.** Copy an approved plan into the card
   `description_markdown`, word for word, before the first edit. The card is the
   record. A chat transcript is not.
4. **The card tracks the state of the work.** Move the card when the state
   changes, not at the end of the task.
5. **The card records the outcome.** Add a comment with the commit sha and the
   files touched before the card leaves In progress.
6. **Every commit names its card.** Prefix the subject with the card key:
   `SYN-4: Apply loudness gain when the EQ graph is off`. The key comes back
   from `list_cards` and `create_card`. Name the card in the PR title too. A
   commit with no card is a commit that broke rule 1.

## The four states

| State | Column | Move the card here when |
| --- | --- | --- |
| To do | 54 | The card exists and the team agrees on the work. |
| In progress | 55 | Work starts. You read code, or you write the plan. |
| Validation | 58 | The code is complete, but nobody has proven it. |
| Done | 56 | The proof exists: a test that failed first, or a real run. |

Keep one card in In progress. Column 56 has `kind: done`, so `move_card` to 56
completes the card by itself. Do not also call `update_card operation=complete`.

Validation is not a formality. It maps to the "prove it" standard in
[done.md](done.md). A card reaches Done only after a test failed first and then
passed, or after a real run showed the behavior.

## What needs no card

- Trivial mechanical edits: a typo, a comment, a format pass, a lockfile.
- Questions, reads and investigations that change no file.

Everything else needs a card. When you are not sure, open the card.
