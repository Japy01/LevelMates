# Interface Phase A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the parchment book into a dashboard:
- a widget kit;
- a 900-wide window with proportional columns;
- pills in the title bar;
- Home as a dashboard of panels;
- "Are you sure?" on destructive actions;
- the feedback line at the book's foot.

**Architecture:**
- **New `Widgets.lua`** (after `Skin.lua`): `W.Panel`, `W.Stat`, `W.Pill`, `W.Chip`, `W.Slot`, `W.ConfirmButton`, `ns.Confirm(text, fn)`.
- **New `Dashboard.lua`:** a frame inside the book shown on the Home tab instead of the rows, filled from existing data (Points, Gear, Meetups, Questhub, Roster, Feed, GuildNotes).
- **`Board.lua`:** the width and `SetColumns` scaling, pills, and the feedback line.
- **`Core.lua`:** `ns.Say` goes to the feedback line while the book is shown; notices keep using chat.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.1); node + fengari tests.

**Spec:** `docs/superpowers/specs/2026-10-12-levelmates-interface-design.md` (phase A)

## Global Constraints

- **Art and fonts:** only the game's (atlas/textures already used in `Skin.lua`; `GameFont*` objects, Morpheus via `Fonts\\MORPHEUS.TTF` for big numbers when the client has it).
- **Window:** `B.WIDTH = 900`. Column widths scale by `(B.WIDTH - 2*B.MARGIN - 4*B.GAP) / sum(widths)`. `B.CARD_COLS = 5`.
- **Confirm:**
  - two clicks within 5 s on buttons;
  - a StaticPopup with Yes/No for menu actions;
  - applies to: cancel a run, withdraw a quest post, delete a goal, remove a wish or offer, take someone out of my run.
- **Feedback line:**
  - while `B.frame:IsShown()`, `ns.Say` text shows at the book's foot for 6 s, then fades over 1.5 s;
  - a click dismisses it;
  - otherwise it prints to chat;
  - `ns.Notice` always prints to chat (and the screen) as today.
- **Pills:** "● N" online (click → Mates); "Discord" when `ns.Discord.Available()`; "0.3: N" when `R.legacy` has entries.
- **Policy:** nothing to chat without a click. Lua 5.1. Ask before pushing or tagging.

## Review Focus

1. **The board at 900 on a small screen** (1024×768 UI): it stays on screen (`SetClampedToScreen`), and the dashboard's columns do not overlap.
2. **An empty guild (alone):** every dashboard panel shows its hint, and the invite text is reachable.
3. **The feedback line during a burst of `ns.Say`:** the last message shows, and nothing piles up.
4. **Confirm buttons reused by redraws** (dungeon panel lines): a pending "Are you sure?" is reset when the line shows another entry.
5. **Ink:** every new text on parchment is registered with `SK.InkFont` (dark enough).

---

### Task 1: Width and proportional columns

- **Test (`tests/board_width.test.lua`):**
  - `B.frame:GetWidth() == 900`;
  - after `ShowTab("mates")` the five header widths plus gaps sum to the usable width (±2 px);
  - the Groups tab shows 5 cards per row (card 6 sits under card 1);
  - every tab still draws (iterate `B.CONTENT_KEYS` and `ShowTab` each without error).
- **Implement:** `B.WIDTH = 900`; in `SetColumns`, scale; `B.CARD_COLS = 5`.
- **Commit:** `feat(book): a wider book; columns grow in proportion`.

### Task 2: Widget kit (`Widgets.lua`)

- **Test (`tests/widgets.test.lua`):**
  - `W.Panel(parent, title)`: it has `.title`, `.right` and `.hint`; `:SetHint(text)` shows the hint; `:SetEmpty(true/false)` toggles it.
  - `W.Stat(parent)`: `:Set(value, label, sub)` sets three texts.
  - `W.Pill(parent)`: `:Set(text)` resizes its width to the text.
  - `W.Chip(parent, text)`: `:SetChecked(bool)`.
  - `W.Slot(parent)`: `:Set(role, name, class)` shows the class icon and name; `:Set(role)` shows the role empty.
  - `W.ConfirmButton(parent, text, fn)`:
    - the first click sets the text to `L.CONFIRM_SURE` and does not call `fn`;
    - a second click within 5 s calls `fn`;
    - after 6 s the text is back;
    - `:Reset()` clears a pending confirmation.
  - `ns.Confirm(text, fn)` shows `StaticPopup_Show("LEVELMATES_CONFIRM")`; `OnAccept` calls `fn`.
  - All texts are registered for ink.
- **Commit:** `feat(ui): a widget kit on parchment: panels, stats, pills, chips, role slots, confirm buttons`.

### Task 3: Confirmations on destructive actions

- **Test (`tests/confirm.test.lua`):**
  - The dungeon panel's Cancel for my run needs two clicks.
  - The Remove button of a slot needs two clicks.
  - The Quests menu "Withdraw", the goal menu "Delete" and the wish/gift "Remove" menus go through `ns.Confirm` (a stubbed `StaticPopup_Show` records it; accepting performs the action).
  - Redrawing a line resets a pending confirm.
- **Implement:**
  - in `DungeonPanel`, button specs gain `confirm = true`, and `setButtons` uses confirm behaviour for those;
  - in `Board` menus, wrap the destructive callbacks in `ns.Confirm`.
- **Commit:** `feat(ui): are you sure? before cancelling, withdrawing, deleting or removing`.

### Task 4: Feedback line

- **Test (`tests/feedback.test.lua`):**
  - With the board shown, `ns.Say("hecho")` sets `B.feedback.text` and does not add to `STUB.printed`; after 8 s it is hidden.
  - With the board hidden, it prints.
  - `ns.Notice` prints even when the board is shown.
  - Three Says in a row → the last one shows.
  - A click hides it.
- **Implement:** `ns.Say` checks `ns.FeedbackTarget` (set by Board): if the board is shown, `B.Feedback(text)`, else print; `ns.Notice` prints directly.
- **Commit:** `feat(ui): what a click did shows at the foot of the book`.

### Task 5: Title pills

- **Test (`tests/pills.test.lua`):**
  - With 2 mates online the pill reads "● 2"; a click shows the Mates tab.
  - With Discord available (stub `C_Discord`) the Discord pill shows; without it, hidden.
  - With `R.legacy` holding one name, "0.3: 1" shows.
- **Commit:** `feat(ui): pills in the title: online, Discord, old versions`.

### Task 6: Home as a dashboard (`Dashboard.lua`)

**Interfaces:**
- Produces:
  - `DB.Build(parent)`;
  - `DB.Refresh()`;
  - fields `DB.stats[1..4]`, `DB.me` (panel), `DB.now`, `DB.runs`, `DB.quests`, `DB.where`, `DB.wall`, and `DB.motd` (a strip).
- On the Home tab, Board hides the rows and the column header and shows the dashboard. Other tabs hide it.

**Test (`tests/dashboard.test.lua`):**
- **Alone:**
  - the four stats (guild level, 1 online, my ilvl, the challenge) are set;
  - each panel shows its hint;
  - the invite text button exists.
- **With data:**
  - two mates in two zones → "where" lists 2 zones;
  - a help request → "now" lists it, and its button sends "on my way" (via `ns.Help.Coming`);
  - a run with 2 joiners → "runs" shows 5 slots, 3 of them filled;
  - a quest post → "quests" lists it;
  - a wall entry → "wall" lists it;
  - the MOTD → the strip shows it;
  - my gear → 17 small squares, filled ones coloured.
- **Redraw:** `ns.Dirty("board")` refreshes the dashboard.

**Commit:** `feat(home): Home as a dashboard: stats, my character, now, next runs, quests, who is where, the wall`.

### Task 7: Docs and build

- CHANGELOG and README (both languages).
- `npm test`; copy to AddOns.
- Commit `docs: the book as a dashboard in the 0.4.0 notes`.
