# Quest Board and Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a guild quest board (Alt+click in the quest log, "me too", a Quests view with filters and notices), shared group quests in Together, and a better map: fixed-size pins, continent view, bundling, a click to route, fresh positions on opening, and stale pins dropped.

**Architecture:**
- **New `Questhub.lua`:** a board record `qh` (one per seeker and quest) and joins `qhj` on the sync layer, plus the quest-log hooks.
- **`Together.lua`:** gains `T.GroupQuests()` from data already received.
- **`GuildMap.lua`:**
  - a layout function `GM.Layout(mapId, scale)`: positions → points on the viewed map, then bundling;
  - the frame code draws from it;
  - the `mpq` message asks for fresh heartbeats when the map opens.
- **Board:** a "Quests" view on the Groups tab, beside Together and Calendar.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.1); node + fengari tests (`npm test`; `tests/*.net.mjs` multi-client).

**Spec:** `docs/superpowers/specs/2026-10-12-levelmates-quests-map-design.md`

## Global Constraints

- **`qh`:**
  - fields `q` (int), `t` (text 40), `l` (int 1-100), `z` (text 30), `o` (objectives, 40), `g` (0/1);
  - life 2 h;
  - id `questId.NameKey(me)`; `idOwner`: the suffix equals `NameKey(owner)`.
- **`qhj`:** no fields; id `adId.NameKey(me)`; `idOwner` the same way.
- **Alt+click:** `hooksecurefunc` on `QuestMapLogTitleButton_OnClick` / `QuestLogTitleButton_OnClick` when present, with `IsAltKeyDown()`; withdraw on `QUEST_TURNED_IN` and `QUEST_REMOVED`.
- **Notices:**
  - for a quest I have, or a group quest within my level ±5;
  - live records only (never catch-up);
  - behind `lfgNotices`.
- **Map:**
  - pin size 18 by default (12–32 in Options); scale = UI scale ÷ canvas scale;
  - bundle 4+ pins within one pin size;
  - never draw me;
  - drop positions older than 300 s;
  - `mpq` at most every 30 s; answers after a random 0.5–6.5 s, only with `sharePos`;
  - a pin's click calls `ns.Help.WaypointTo(mapId, x, y, name)`.
- **Policy:** whispers, invites and routes only from clicks; nothing to chat. Lua 5.1. Ask before pushing or tagging.

## Review Focus

1. A quest log entry without a level, tag or objectives (an "auto-complete" or a header): the post still works, with empty fields.
2. Two clients (Classic and Mainline quest logs) present: the hook must not double-post on one Alt+click.
3. Continent conversion when `C_Map.GetWorldPosFromMapPos` returns nil or the point lies on another continent: no pin and no error.
4. A guildmate with a surname on the map: the label shows the first name, and the tooltip and route use the full name.
5. A `mpq` storm (many players opening the map at once): each client answers at most once per 30 s.

---

### Task 1: Quest board core (`Questhub.lua`)

**Files:**
- Create: `LevelMates/Questhub.lua` (`.toc` after `Meetups.lua`)
- Locales: `QH_*`
- Tests: `tests/questhub.test.lua`, `tests/questhub_sync.net.mjs`

**Interfaces:**
- Produces:
  - `QH.Post(questId)` → bool (reads my log: title, level, header, objectives, group tag).
  - `QH.Withdraw(questId)`.
  - `QH.Toggle(questId)`.
  - `QH.MineFor(questId)` → bool.
  - `QH.List(filter)` returns `{ id, q, t, l, z, o, g, by, at, joined = {names} }`, newest first. The filter is `"all"`, `"zone"`, `"level"` or `"group"`.
  - `QH.MeToo(id)` and `QH.NotMe(id)`.
  - `QH.IJoined(id)`.
  - `QH.MyQuests()` returns my log entries `{ id, title, level }`.
  - Event `LM_QUESTHUB_CHANGED`.

- [ ] **Step 1: failing unit test.** Use the stub's quest log (`C_QuestLog.GetInfo`/`GetNumQuestLogEntries` as other tests set it, for example `STUB.quests`).
  - `QH.Post(id)` sends a `qh` record whose fields match my log.
  - `QH.Toggle(id)` withdraws it (an `x` with `t = "qh"`).
  - `QUEST_TURNED_IN` with that id withdraws a live post.
  - Mario's post of a quest I have notices me once ("you have it too"); the same post again does not.
  - A post whose id belongs to someone else's key is refused.
  - "Me too" on Mario's post sends `qhj` with id `post.NameKey(me)`, and `QH.List()[1].joined` contains me.
  - A post handed over at login (whisper) does not notice.
  - Filters: zone (my map's header), level ±5, group.
- [ ] **Step 2: failing net test:** Ana posts and leaves; Cris logs in and sees Ana's post within 2 h.
- [ ] **Step 3:** implement (Sync.Define with `idOwner`; `onChange` → notices and the event).
- [ ] **Step 4:** both pass; `npm test` green.
- [ ] **Step 5:** commit `feat(quests): a guild quest board: post from the quest log, me too, notices`.

### Task 2: The quest log hook

**Files:**
- Modify: `Questhub.lua`
- Test: `tests/questhub_hook.test.lua`

- [ ] **Step 1: failing test.**
  - Define globals `QuestMapLogTitleButton_OnClick` and `QuestLogTitleButton_OnClick` before load, and set `IsAltKeyDown = function() return true end`.
  - Call one with a button whose `questID` (or `questLogIndex`) points to a quest → one `qh` post.
  - Call the other for the same quest within 0.5 s → no second toggle.
  - Without Alt held → nothing.
- [ ] **Step 2:** fail. **Step 3:** hooks, installed at `LM_WORLD` and on `ADDON_LOADED` of `Blizzard_UIPanels_Game` / `Blizzard_QuestLog`. The id comes from `button.questID`, or `C_QuestLog.GetInfo(button.questLogIndex or button:GetID()).questID`. Debounce 0.5 s per quest. **Step 4:** pass; suite. **Step 5:** commit `feat(quests): Alt+click a quest in the log to post or withdraw it`.

### Task 3: Quests view and menu on the Groups tab; group quests in Together

**Files:**
- Modify: `Board.lua` (a "Quests" button and view, filters as a cycling button, row menu, tooltip), `Together.lua` (`T.GroupQuests()`), and the Together view (a section after the suggestions)
- Locales
- Test: `tests/questhub_ui.test.lua`

**Interfaces:**
- Produces: `T.GroupQuests()` returns `{ { q, title, with = {names} } }`, for quests in my log tagged group, elite or dungeon (via `C_QuestLog.GetQuestTagInfo`) that are not complete, and that at least one online mate also has (`R.mates[name].quests[q]`).

- [ ] **Step 1: failing test.**
  - The Groups tab shows `B.questsButton`.
  - A click shows rows carrying `questEntry`.
  - A row click opens a menu with Me too / Whisper / Invite (mine: Withdraw / Invite all).
  - `B.QuestFilter` cycles all → zone → level → group.
  - Together lists a shared group quest as a `togetherEntry` with `quest`.
  - The "Search for a quest" button opens a menu of my quests.
- [ ] **Step 2:** fail. **Step 3:** implement (same patterns as Together and Calendar: `B.lfgQuests` exclusive with the other views; `PageKey` `"questsPage"`). **Step 4:** pass; suite. **Step 5:** commit `feat(quests): the Quests view on the Groups tab; group quests in common in Together`.

### Task 4: Map layout, bundling, continent and stale pins

**Files:**
- Modify: `GuildMap.lua` (`GM.Layout`), `Roster.lua` (`m.posAt` when x/y arrive)
- Test: `tests/guild_map_layout.test.lua`

**Interfaces:**
- Produces: `GM.Layout(mapId, canvasW, canvasH, pinPx)` returns `{ { x, y, names = {…}, mapId, mx, my } }`, in canvas pixels:
  - single pins carry one name;
  - bundles carry 4+ names;
  - me excluded.

- [ ] **Step 1: failing test.**
  - With mates on map 1429, `Layout(1429, 1000, 700, 18)` gives one pin per mate at `x/100*w`.
  - 4 mates within 10 px → one bundle with 4 names; 3 → three pins.
  - Stub a continent: `C_Map.GetWorldPosFromMapPos`/`GetMapPosFromWorldPos` map zone 1429 to continent 1415 with a known offset → the pins appear on 1415.
  - A nil world position → nothing, no error.
  - A mate whose `posAt` is older than 300 s → absent.
  - I am never in it.
- [ ] **Step 2:** fail. **Step 3:** implement:
  - zone match direct;
  - otherwise world-position conversion (`pcall`; accept `(continentId, vector)` returns or a vector with `.x`/`.y`);
  - points outside 0–1 are dropped;
  - greedy bundling sorted by y, then x, then name.
- [ ] **Step 4:** pass; suite. **Step 5:** commit `feat(map): pins on continents, bundled when crowded, old ones dropped`.

### Task 5: Map frames, click to route, fresh positions on opening

**Files:**
- Modify: `GuildMap.lua` (draw from `Layout` with a scale-compensated size; reuse pins; bundle disc with count and tooltip; first-name labels; OnClick → route; redraw via `ns.OnRedraw("map")`; `mpq` on open with a 30 s cooldown; answer `mpq` with `R.SendHeartbeat(true)` after a random 0.5–6.5 s when `sharePos`, at most once per 30 s)
- Modify: `Settings.lua` (pin size slider 12–32, names on pins)
- Test: `tests/guild_map_frames.test.lua`, `tests/map_request.net.mjs`

- [ ] **Step 1: failing tests.**
  - The pin size is the same at canvas scale 1 and 2 (`p:GetScale()` = UI scale ÷ canvas scale).
  - A bundle shows its count text.
  - A click on a pin calls `WaypointTo` with the mate's name.
  - Opening the map sends `mpq` once within 30 s.
  - **Net:** Ana opens the map; Ben (sharePos on) answers with a heartbeat; Cris (sharePos off) does not.
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass; suite. **Step 5:** commit `feat(map): fixed-size pins, a click routes there, fresh positions when the map opens`.

### Task 6: Docs and build

- CHANGELOG 0.4.0 bullets: the quest board, group quests in Together, and the map.
- README in both languages:
  - features;
  - privacy: the quest board posts your quest's title and objectives only when you post it.
- `npm test`; copy to AddOns; commit `docs: quest board and map in the 0.4.0 notes`.

---

## Self-review notes

- **Spec coverage:**
  - §1: Tasks 1–3;
  - §2: Task 3;
  - §3: Tasks 4–5;
  - §4: Tasks 1 and 5;
  - §6: the tests of each task;
  - campfires are out by spec.
- **Interfaces:**
  - `QH.Toggle` is used by Task 2;
  - `QH.List`, `QH.MeToo` and `QH.MyQuests` by Task 3;
  - `GM.Layout` by Task 5;
  - `T.GroupQuests` by Task 3 (the Together view).
