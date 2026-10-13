# Unified Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One idea, the **group**: what (an activity from the catalogue or free text), when (Now or a day and hour), size and slots per role. Shown the same everywhere: the Groups view, the catalogue, the activity panel, Home and Discord. Raids, PvP and "other" join dungeons.

**Architecture:**
- **New `Activities.lua`:** the catalogue. It wraps `Dungeons.lua` (ids 1–14 unchanged) and adds raids (101+) and PvP (201+), with default sizes and caps.
- **Records:** `LFG.lua` (Now, messages `lfg`/`lfj`) and `Meetups.lua` (scheduled, `qd`/`qj`/`qm`) gain the same fields:
  - `d`: activity;
  - `x`: size;
  - `c`: caps;
  - `t`: free name.
- **Slots:** generalised to per-group caps; role `A` means "any".
- **New `Groups.lua`:** merges both into one view list.
- **Widgets:** `W.GroupCard` replaces `W.RunCard`: slots up to 5, role counters above.
- **Views:**
  - `GroupsView.lua` replaces `RunsView.lua`;
  - the dungeon cards become the Catalogue view, with chips;
  - `DungeonPanel.lua` is rebuilt on the widgets;
  - Home's runs panel becomes "Groups".

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.1, Retail-engine API); node + fengari tests (`npm test`; one test: `node tools/run-lua-test.mjs LevelMates tests/X.test.lua`; multi-client: `tests/*.net.mjs` with `tools/lua-net.mjs`).

**Spec:** `docs/superpowers/specs/2026-10-13-levelmates-groups-design.md`

## Global Constraints

- **Dungeon ids 1–14 never change** (they travel in messages and goals). Raids are 101+, PvP 201+, "free raid" 190, "world PvP" 290, "other" 300.
- **Caps:**
  - dungeon `T1H1D3`;
  - raid by size: 10 → `T2H3D5`, 20 → `T3H5D12`, 40 → `T5H10D25`; the leader may change a raid's caps;
  - PvP, world PvP and other: no roles, role `A`, cap = size.
- **Sizes:** world PvP 5–40; other 2–40; battlegrounds fixed (Warsong 10, Arathi 15, Alterac 40).
- **Free name:** at most 40 letters, cleaned like notes (no `|` codes); used by free raid, world PvP and other.
- **Messages:** fields `d`, `x`, `c` (`T2H3D5` form) and `t` on both `lfg` and `qd`. A message with an unknown `d` and no `t` is ignored. Max 240 bytes per message as always.
- **Policy:** Publish, Join, Leave, Invite all, Cancel/Withdraw and Discord run only from clicks. Lua 5.1. Only the game's art. Text on parchment inked. Ask before pushing or tagging.
- **Names:**
  - the section is "Grupos" / "Groups";
  - its views are "Grupos" and "Catálogo";
  - the catalogue chips are "Mazmorras / Bandas / JcJ".

## Review Focus

1. **A 40-person raid with joins arriving out of order and a leader line-up (`qm`) that names more people than the caps:** the extras wait, nobody is placed twice, and the counters never go over the caps.
2. **A free name with pipes, links or 300 letters**, Now and scheduled: it is cut and cleaned on send and on receive, and the Discord line stays at most 236 bytes.
3. **Switching the form's type while a role is chosen** (Dungeon/Tank → Other): the role row hides and the group publishes with role `A`; switching back restores a real role.
4. **My own Now group:** it shows on Home and in Groups with Withdraw, survives a /reload as today, and disappears from every view when withdrawn or full.
5. **A raid or PvP activity the server does not have:** removing it from the catalogue list does not break a received group that names it (shown by its name or "#id"; it does not crash).

---

### Task 1: The activity catalogue

**Files:** create `LevelMates/Activities.lua` (in the .toc right after `Dungeons.lua`); locales (raid and PvP names, type names); test `tests/activities.test.lua`.

**Interfaces:**
- **Produces:** `ns.Activities` as `A`:
  - `A.KINDS = { "d", "r", "p", "o" }` (dungeon, raid, PvP, other);
  - `A.Get(id)` → `{ id, kind, key, min, max, size, sizes, roles, art, coords, free }` or nil:
    - `free` is true for 190, 290 and 300 (named by the player);
    - `roles` is false for PvP and other;
  - `A.List(kind)` → the catalogue of a kind, in order (dungeons via `ns.Dungeons.Sorted()`);
  - `A.Name(id, text)` → the free text when `free` and text is given, else the localised name, else `"#" .. id`;
  - `A.Caps(id, size, custom)` → `{ T = n, H = n, D = n }` or `{ A = size }`; `custom` is a `"T2H3D5"` string that overrides, and is honoured only for raids;
  - `A.EncodeCaps(caps)` / `A.DecodeCaps(text)`;
  - `A.CleanName(text)` → stripped of `|` codes, trimmed, at most 40 letters;
  - `A.SizeOf(id, x)` → `x` clamped to the activity's range, or its default.
- **Consumes:** `ns.Dungeons` (`Get`, `Sorted`, `Name`, `Art`).

**Catalogue rows** (sizes; art only from the game's loading screens, nil when unknown):
- **raids:**
  - 101 Molten Core 40 · 102 Onyxia 40 · 103 Zul'Gurub 20 · 104 Blackwing Lair 40;
  - 105 Ruins of Ahn'Qiraj 20 · 106 Temple of Ahn'Qiraj 40 · 107 Naxxramas 40;
  - 190 free raid, sizes {10, 20, 40}.
- **PvP:** 201 Warsong Gulch 10 · 202 Arathi Basin 15 · 203 Alterac Valley 40 · 290 world PvP, 5–40.
- **other:** 300, 2–40.

- [ ] **Step 1: Write the failing test** `tests/activities.test.lua`:
  - **Ids and names:**
    - `A.Get(5).kind == "d"` and `A.Name(5) == ns.Dungeons.Name(5)`;
    - `A.Get(101).size == 40` and `A.Caps(101)` is `{T=5,H=10,D=25}`;
    - `A.Caps(190, 20)` is `{T=3,H=5,D=12}`, and `A.Caps(190, 10, "T1H2D7")` is `{T=1,H=2,D=7}` (custom honoured for raids);
    - `A.Caps(5, 5, "T3H1D1")` is still the dungeon's `{T=1,H=1,D=3}` (custom ignored);
    - `A.Caps(203)` is `{A=40}`; `A.Caps(290, 12)` is `{A=12}`; `A.Caps(300, 99)` is `{A=40}` (clamped).
  - **Free names:**
    - `A.Name(300, "farmear seda") == "farmear seda"`; `A.Name(999) == "#999"`;
    - `A.CleanName("|cffff0000rojo|r " .. string.rep("x", 60))` has no `|` and at most 40 letters.
  - **Encoding:** `A.EncodeCaps({T=2,H=3,D=5}) == "T2H3D5"` and round trip.
  - **Lists:**
    - `A.List("d")` has the 14 dungeons in `ns.Dungeons.Sorted()` order;
    - `A.List("r")` starts with 101 and ends with 190;
    - `A.List("p")` ends with 290.
- [ ] **Step 2:** run it and see it fail.
- [ ] **Step 3:** implement. Add the locale keys `ACT_MC`, `ACT_ONY`, `ACT_ZG`, `ACT_BWL`, `ACT_AQ20`, `ACT_AQ40`, `ACT_NAXX`, `ACT_RAID_FREE`, `ACT_WSG`, `ACT_AB`, `ACT_AV`, `ACT_WPVP`, `ACT_OTHER`, `KIND_d`, `KIND_r`, `KIND_p`, `KIND_o` to both locales (`tests/policy.test.mjs` checks both have every key).
- [ ] **Step 4:** run `npm test` and see it pass.
- [ ] **Step 5:** commit `feat(groups): a catalogue of activities: dungeons, raids, PvP and anything else`.

### Task 2: Groups carry their activity, size and caps (Now and scheduled)

**Files:**
- Modify:
  - `LevelMates/LFG.lua`: `G.Post` takes a spec; fields `d x c t`; slots and joins with caps;
  - `LevelMates/Meetups.lua`: `M.Create` takes a spec; `qd` fields; `M.Slots` with caps; `A` role;
  - `LevelMates/Discord.lua`: the line with its kind and caps;
  - `LevelMates/Comm.lua`: validators for the new fields;
  - the locales.
- Tests: `tests/groups_records.test.lua`, `tests/groups_sync.net.mjs`; update the LFG, meetup and Discord tests for the new signature.

**Interfaces:**
- **Produces:**
  - `ns.LFG.Post(spec)` and `ns.Meetups.Create(spec)`, where
    `spec = { d = id, x = size?, c = "T2H3D5"?, t = text?, role = "T"|"H"|"D"|"A", note = text?, at = minutes? (Meetups only), discord = bool? }`.
    - Both return true or false. A false return names its reason with `ns.Say`.
    - `G.Post(dungeonId, roles, note)` stays as a thin wrapper, for old callers until Task 4 removes them.
  - The views carry the new fields:
    - an ad (`G.ads[id]`, `G.mine`) and a meetup view (`M.List()` entries) carry `d`, `size`, `caps` (decoded), `t`, `by`/`name`, `role`, `joined`;
    - the ad also carries `at = nil`.
  - Slots:
    - `M.Slots(m)` returns `slots[role]` for each role in `caps` (T/H/D, or A), plus `waiting` and `confirmed`;
    - `M.Free(m, role)` uses `caps`; `M.IsFull(m)`;
    - `ns.LFG.Slots(ad)` returns the same shape: the leader in their role, then the joins in arrival order while there is room, the rest waiting.
  - Joining: `ns.LFG.Join(id, role)` and `M.Join(id, role)` accept `"A"` only for groups without roles, and T/H/D only for groups with them.
  - Discord: `ns.Discord.Line(kind, m, who, role)` puts the type first, using `A.Name`. A group without roles lists "faltan: N".
- **Consumes:** `ns.Activities` (Task 1).

- [ ] **Step 1: Write the failing tests:**
  - **`tests/groups_records.test.lua`:**
    - **Now:**
      - `ns.LFG.Post{ d = 190, x = 20, t = "Jefe de mundo: Azuregos", role = "H" }` sends `lfg` with `d=190, x=20, t=…`;
      - `ns.LFG.Slots(G.mine)` has `H = {me}` and the caps T3/H5/D12;
      - another client joining as T (received `lfj`) is placed;
      - an 11th "A" join to a world-PvP group of 10 waits.
    - **Scheduled:**
      - `M.Create{ d = 203, at = M.Now() + 60, role = "A" }` creates a `qd` with `d=203` and no `x`;
      - its slots are `{ A = { me } }`; 40 joins as A → 40 placed, the 41st waits.
    - **Join roles:**
      - joining a raid as A is refused;
      - joining WSG as T is refused (no roles).
    - **Free names:**
      - a received `lfg` with `t` holding `|c…|r` and 60 letters is stored cleaned and cut;
      - a received `lfg` with `d=999` and no `t` is ignored.
    - **Discord:** with a spec of raid 101 (40), `ns.Discord.Line("new", m)` starts with `[LevelMates]` and the raid name, says "faltan: 5 tanques, 10 sanadores, 24 daño" (the leader is one damage), and is at most 236 bytes even with a 40-letter name and note.
  - **`tests/groups_sync.net.mjs`:** two clients:
    - A posts a Now raid 190 (20, custom caps `T2H4D14`, name "Azuregos") and a scheduled Alterac;
    - B sees both with the same caps and names, joins the raid as H, and A's slots show B in H.
- [ ] **Step 2:** run them and see them fail.
- [ ] **Step 3:** implement. Keep the old dungeon-only paths working through the spec, update `Comm.lua`'s validators (`C.V`) for `x` (number 2–40), `c` (`^[THD%d]+$` or `^A%d+$`), `t` (string, ≤ 60 before cleaning) and `d` (number), and update the old LFG, meetup, Discord and runs tests that call `Post(d, roles, note)` / `Create(d, at, note, role, discord)` through the wrappers or the new spec.
- [ ] **Step 4:** `npm test` passes (Lua and net tests).
- [ ] **Step 5:** commit `feat(groups): every group carries its activity, size and slots per role, Now and scheduled`.

### Task 3: One list of groups, and the group card

**Files:**
- Create: `LevelMates/Groups.lua`.
- Modify:
  - `LevelMates/Widgets.lua`: `W.GroupCard` replaces `W.RunCard`; keep `W.RunCard = W.GroupCard` as an alias until Task 4;
  - `LevelMates/Dashboard.lua`: uses `W.GroupCard`;
  - the locales.
- Test: `tests/group_card.test.lua`.

**Interfaces:**
- **Produces:**
  - `ns.Groups.List(filter)` → views, newest Now first, then scheduled by time:
    `{ src = "now"|"meet", id, d, name (A.Name), kind, at (nil for Now), by, mine, myRole, caps, size, slots (as M.Slots), count, full, note }`.
    - `filter` is an optional activity id;
    - Now entries are `ns.LFG` ads, mine included; scheduled entries are `M.List()` not yet started.
  - `ns.Groups.Join(g, role)`, `Leave(g)`, `Cancel(g)` (withdraw for Now) and `InviteAll(g)` route to LFG or Meetups.
  - `W.GroupCard(parent, withButtons)` with:
    - `:Set(g)`;
    - `.text` ("Ahora · Minas de la Muerte · Mario · nota", or "mar 21:00 · …");
    - `.slots[1..5]`, shown when `size <= 5`;
    - `.counters`, three rows (T/H/D) with a bar and "2/5", or one row "12/40" for A, shown when `size > 5`;
    - `.buttons[1..3]`.
  - The card's buttons:
    - **mine:** Invite all, Cancel or Withdraw (confirm);
    - **joined:** Leave;
    - **otherwise:** Join, which opens a menu of the free roles, or joins directly as A when the group has no roles.
  - A click on the card body opens a small list of who goes (`B.OpenGroupMembers(g)`, a menu with names by role).
  - `W.GROUPCARD_H = 64`.

- [ ] **Step 1: Write the failing test** `tests/group_card.test.lua`:
  - **List:** a Now dungeon ad of mine, a Now raid 190/20 of Mario's and a scheduled Alterac → `ns.Groups.List()` has the two Now first (mine included) and then the scheduled one.
  - **Small card:** shows 5 slots and hides the counters.
  - **Raid card:** shows the counters "0/3", "1/5", "0/12" (Mario as H) and hides the slots.
  - **No roles:** the Alterac card shows one counter "1/40".
  - **Buttons:**
    - Join on the raid opens the free roles; picking T joins;
    - Join on Alterac joins as A with no menu;
    - my Now card shows Withdraw, which takes two clicks and then my ad is gone.
  - **Dashboard:** still shows its cards through `W.GroupCard`.
- [ ] **Step 2:** run it and see it fail.
- [ ] **Step 3:** implement. The counters use the Skin's bar textures, inked labels and role icons (`W.ROLE_ICON`).
- [ ] **Step 4:** `npm test` passes.
- [ ] **Step 5:** commit `feat(groups): one list of groups, and a card that shows slots or role counters`.

### Task 4: The Groups section: Groups view with the form, and the Catalogue

**Files:**
- Create: `LevelMates/GroupsView.lua`, replacing `RunsView.lua` (delete it and remove it from the .toc).
- Modify:
  - `LevelMates/Board.lua`: the tab label "Grupos"; the two view buttons **Grupos / Catálogo** replace the old Calendar toggle; the Catalogue grid draws `A.List(kind)` with a chip row; card counts from `ns.Groups`; chat ads stay on the cards;
  - `LevelMates/MeetDialog.lua`: kept for "Create group here" fallbacks, now building a spec;
  - the locales.
- Tests: `tests/groups_view.test.lua`; rewrite `runs_view.test.lua` and `calendar.test.lua` into it; adapt the `board_lfg` tests to the Catalogue.

**Interfaces:**
- **Produces:**
  - `ns.GroupsView` as `GV`:
    - `GV.Build(parent)`, `GV.Refresh()`;
    - sections `GV.now`, `GV.soon`, `GV.later`, `GV.chat` (panels: cards for now and soon, items for later and chat);
    - `GV.form` with fields `kind`, `d`, `name` (EditBox for free ones), `size` (button with a menu), `when` (0 = Now, 1..7 = today..+6), `hour`, `minute`, `note`, `role`, `discord`, `publish`;
    - `GV.At()` (same rule as `MeetDialog.At`);
    - `GV.Prefill(d)`: sets the kind and activity and shows the view.
  - `B.groupsView` is `"groups"` or `"catalog"` (saved in `ns.char`); `B.catalogKind` is `"d"`, `"r"` or `"p"`.
- **Consumes:** Tasks 1–3.

- [ ] **Step 1: Write the failing test** `tests/groups_view.test.lua`:
  - **The section:**
    - its tab label is `L.TAB_LFG == "Grupos"` (esES);
    - the view buttons switch between `GV.frame` and the catalogue cards.
  - **Sections:**
    - a Now ad from Mario and mine → both in `GV.now`;
    - a scheduled run today → `GV.soon`; one in 3 days → `GV.later`;
    - a chat ad → `GV.chat.items[1]`.
  - **Form:**
    - type Raid: the activity menu lists raids, and the size button shows (10/20/40); choose 190, name "Azuregos", 20, when Now, role H → Publish sends `lfg` with `d=190, x=20, t="Azuregos"`;
    - type Other with role T chosen before: the role row hides, and Publish sends role A;
    - when Tomorrow 21:30 → creates a `qd` at `GV.At()` (equal to `MeetDialog.At()` for the same day and hour);
    - with no activity chosen (and no name for free types), Publish is disabled.
  - **Catalogue:**
    - the chips Mazmorras, Bandas and JcJ show `A.List(kind)` cards;
    - a card counts the groups of its activity;
    - a click opens its panel.
  - `GV.Prefill(5)` from the panel opens the Groups view with Dungeon and 5 chosen.
- [ ] **Step 2:** run it and see it fail.
- [ ] **Step 3:** implement.
  - **Layout:** like the dashboard. Left 58%: Now (2 cards), Today and tomorrow (2 cards), Later (4 items), Chat (4 items). Right: the form.
  - **Bottom bar:** "Look for group" and "My role" leave it; the form covers them. Together and Quests stay as buttons; the bottom-left corner holds the two view buttons.
- [ ] **Step 4:** `npm test` passes.
- [ ] **Step 5:** commit `feat(groups): the Groups section: Now, today, later and chat beside the form, and a catalogue of dungeons, raids and PvP`.

### Task 5: The activity panel, rebuilt

**Files:**
- Modify: `LevelMates/DungeonPanel.lua` (rewrite the body on the widgets; keep `DP.Open(id)`, `DP.Refresh()` and `DP.frame`); the locales.
- Test: `tests/activity_panel.test.lua`; adapt the old `dungeon_panel*` and `confirm` tests.

**Interfaces:**
- **Produces:** `DP.Open(id)` works for any activity id. Its parts:
  - `DP.header`: art and name, and the levels for dungeons;
  - `DP.groups`: a `W.Panel` with up to 3 `W.GroupCard`s, plus "+N more";
  - `DP.mates`: items "name · level" with Whisper and Invite buttons;
  - `DP.chat`: items with Whisper;
  - `DP.create`: a button that calls `ns.GroupsView.Prefill(id)`.
- **Consumes:** Tasks 1–4.

- [ ] **Step 1: Write the failing test** `tests/activity_panel.test.lua`:
  - **Dungeon 5:**
    - `DP.Open(5)` shows its name;
    - a Now ad and a run for 5 → 2 cards in `DP.groups`;
    - a mate of level 20 is in `DP.mates`, and Invite calls `C_PartyInfo.InviteUnit` from the click;
    - a chat ad is in `DP.chat`;
    - `DP.create` calls Prefill with 5.
  - **Raid 101:** `DP.Open(101)` shows no levels and works with no groups (hint shown).
  - **Cancel:** my run's Cancel takes two clicks, and a `DP.Refresh()` between keeps the question.
- [ ] **Step 2:** run it and see it fail.
- [ ] **Step 3:** implement. The window is 360 wide beside the book, parchment-skinned, every text inked.
- [ ] **Step 4:** `npm test` passes.
- [ ] **Step 5:** commit `feat(groups): the activity panel rebuilt: its groups as cards, mates of its level, chat ads, create here`.

### Task 6: Home shows groups, mine included

**Files:**
- Modify: `LevelMates/Dashboard.lua` (`DB.runs` becomes `DB.groups` with the title "Grupos"; LFG leaves "Now"); the locales.
- Test: update `tests/dashboard.test.lua` and `tests/self_row.test.lua`.

- [ ] **Step 1: Write the failing test** (in `dashboard.test.lua`):
  - my Now ad shows as the first card of `DB.groups`, with Withdraw;
  - a scheduled run follows it;
  - `DB.now` no longer lists LFG ads, only help, gifts and the trainer;
  - the empty hint points to the Groups section.
- [ ] **Step 2:** run it and see it fail.
- [ ] **Step 3:** implement.
- [ ] **Step 4:** `npm test` passes.
- [ ] **Step 5:** commit `feat(home): groups on Home, Now first, mine included`.

### Task 7: Docs and build

- CHANGELOG (0.4.0): groups unified; raids, PvP and other; the catalogue; the panel.
- README in both languages: the Groups section replaces the Dungeons and Runs text; commands unchanged.
- Run `npm test`, then copy to AddOns.
- Commit `docs: unified groups in the 0.4.0 notes`.
