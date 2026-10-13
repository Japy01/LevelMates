# Interface Phase B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four additions to the book:
- runs as cards, with a Create-run form inside Groups;
- a notification tray, with a count on the minimap button and a strip under the minimap;
- an optional level bar;
- a banner on level-up.

**Architecture:**
- **New `RunsView.lua`:** a frame inside the book, shown in Groups → Runs (the old Calendar view) instead of the rows, built from the phase A widgets. The run card moves into `Widgets.lua` as `W.RunCard`, so the dashboard and the Runs view share it.
- **New `Tray.lua`:** keeps notices. `ns.Notice` adds to it.
- **New `LevelBar.lua`:** reads XP and kill messages and draws a small movable bar.
- **New `Ding.lua`:** shows the level-up banner.
- **Touched:** Board, Dashboard, MinimapButton, Settings, Core, the locales, and the callers of `ns.Notice` that point somewhere.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.1, Retail-engine API); node + fengari tests (`npm test`; one test: `node tools/run-lua-test.mjs LevelMates tests/X.test.lua`).

**Spec:** `docs/superpowers/specs/2026-10-12-levelmates-interface-design.md` (section "Fase B")

## Global Constraints

- **Art and fonts:** only the game's (no other addons' files). Text on parchment goes through `ns.Skin.InkFont`; text on dark bands (title, minimap, strip) is light and not inked.
- **Policy:**
  - Nothing goes to chat, invites or whispers without a click; "Publish" and "Invite all" run only from their buttons.
  - Lua 5.1.
  - Ask before pushing or tagging.
- **Tray:** the last 30 notices, none older than 2 hours. Opening the tray marks all as read.
- **Strip:**
  - shows the newest notice for 10 s;
  - waits while I am in combat;
  - never shows in the first 20 s after entering the world;
  - switch "Strip under the minimap" (`settings.stripNotices`, on by default), turned off by quiet mode.
- **Level bar:**
  - off by default (`settings.levelBar`); `/lm barra` and `/lm bar` toggle it;
  - movable, with a lock (`settings.levelBarLocked`);
  - XP per hour over the last 15 minutes.
- **Banner:** about 8 s; a click closes it; switch `settings.dingBanner` (on), turned off by quiet mode.
- **Runs view:**
  - **left:** today and tomorrow as cards with 5 slots and buttons (Join by free role / Leave / Invite all / Cancel); later days below as a list.
  - **right:** the form: dungeon, day chips (Today, Tomorrow, the next 5 days), hour, minute, note, my role (chips), "Announce on Discord" with its reason when unavailable, **Publish**.
  - The standalone MeetDialog stays for dungeon cards.

## Review Focus

1. **A burst of 30+ notices while in combat:** the tray caps at 30; the strip shows only the newest once combat ends (no queue of 30 strips), and the minimap count says 30.
2. **A /reload in the middle of a level:** the level bar keeps the time in level (saved in `ns.char`), and XP per hour restarts empty instead of dividing by zero.
3. **The form's day and hour across midnight and summer time:** "Tomorrow 00:30" made at 23:50 is tomorrow, not today; it uses `MeetDialog.At`'s `time{}` rule.
4. **A run whose leader or joiners are offline:** the cards show names without a class icon and no wrong data. Cancel needs two clicks, and a redraw between them keeps "Are you sure?" (the stable-key rule from the phase A fix).
5. **Leveling twice quickly (quest turn-in chains), or a level-up in combat:** one banner per level, the newest replacing the old; the level bar's kills reset per level.

---

### Task 1: The run card as a widget, and the Runs view in Groups

**Files:**
- Modify:
  - `LevelMates/Widgets.lua` (add `W.RunCard`);
  - `LevelMates/Dashboard.lua` (use it);
  - `LevelMates/Board.lua`: the calendar button label, show/hide the view like the dashboard, `B.CAL_DAYS` list moved to the view;
  - `LevelMates/LevelMates.toc` (add `RunsView.lua` after `Dashboard.lua`);
  - `LevelMates/Locales/enUS.lua` and `esES.lua`.
- Create: `LevelMates/RunsView.lua`.
- Test: `tests/runs_view.test.lua`; update the `dashboard.test.lua` and calendar tests that read rows.

**Interfaces:**
- **Produces:**
  - `W.RunCard(parent)` returns a card with:
    - `.text`;
    - `.slots[1..5]` (`W.Slot`);
    - `.buttons[1..3]` (confirm-aware buttons);
    - `:Set(m)`: fills the text and slots from `ns.Meetups.Slots(m)` in the order T, H, D, D, D; class from the roster or `UnitClass` for me; nil class → no icon.
  - `:Set(m)` also sets the buttons:
    - **leader:** Invite all (`ns.Board.InviteAll(names)`), Cancel (confirm);
    - **joined:** Leave;
    - **otherwise:** Join, which opens a menu of the free roles (`M.Free(m, role)`) and calls `M.Join(m.id, role)`.
  - `:Set(nil)` hides the card.
  - Pending confirm is kept while the card shows the same `m.id`.
  - `ns.RunsView`: `RV.Build(parent)`, `RV.Refresh()`, `RV.cards`, `RV.later` (a `W.Panel` with items), `RV.form` (fields `dungeon`, `dayOffset`, `hour`, `minute`, `note`, `role`, `discord`, `publish`).
  - `RV.At()` returns minutes since 1970 for the form's day, hour and minute, using the same `time{}` rule as `MeetDialog.At`.
- **Consumes:**
  - `ns.Meetups` (`List`, `Slots`, `Free`, `Join`, `Leave`, `Cancel`, `Create`, `When`, `Now`, `MyRole`);
  - `ns.Discord.Available()`;
  - `ns.Dungeons.Sorted()`, `Name`;
  - `ns.Widgets` (Panel, Chip, Slot, ConfirmButton).

- [ ] **Step 1: Write the failing test** `tests/runs_view.test.lua`:
  - Groups → Runs shows `RV.frame` and hides the rows.
  - **Cards:**
    - a sample run today and one tomorrow → 2 cards shown; a run in 3 days goes to `RV.later.items[1]`;
    - a card shows 5 slots, with the leader filled.
  - **My run:**
    - its buttons are Invite all and Cancel;
    - Cancel takes two clicks; a `RV.Refresh()` between them keeps "Are you sure?".
  - **Someone else's run:** Join opens the role menu (stub `MenuUtil.CreateContextMenu`); choosing H calls `M.Join(id, "H")`.
  - **Form:**
    - choose dungeon 5, the Tomorrow chip, hour 21, minute 30 → `RV.At()` equals `MeetDialog`'s rule for that day;
    - Publish creates the run (`#M.List(5)` grows) and resets the note.
  - **Discord:** without Discord, the checkbox is disabled and the reason shows.
  - **The dashboard** still shows its run cards through `W.RunCard` (`DB.runs.cards[1].slots`).
- [ ] **Step 2:** run it and see it fail on `ns.RunsView` being nil.
- [ ] **Step 3:** implement:
  - **`W.RunCard`:** move `buildRuns`/`refreshRuns`' card code out of the Dashboard, and add the buttons.
  - **`RunsView.lua` layout** inside the same content area as the dashboard (anchor TOPLEFT `B.MARGIN, -(B.TOP - 4)`, BOTTOMRIGHT `-B.MARGIN, B.BOTTOM + 30`):
    - **left column (58%):** up to 4 cards (68 px each), then the "later" panel (6 items, a click opens `B.OpenMeetMenu(m)`);
    - **right column:**
      - the form panel, with the dungeon button opening a menu of `D.Sorted()`;
      - 7 day chips, laid out 4 + 3;
      - hour and minute buttons with menus (minutes 00/15/30/45);
      - a note `EditBox` (`InputBoxTemplate`, 40 letters);
      - 3 role chips;
      - the Discord checkbox and its reason;
      - Publish → `M.Create(dungeon, RV.At(), note, role, discord)`.
    - The Publish button is disabled until a dungeon is chosen.
  - **Board:**
    - `B.lfgCalendar` now shows `RV.frame` (rows `list = {}`, `rows = ROWS`, `emptyText = ""`, column strip hidden), mirroring Home's dashboard branch;
    - the heading becomes `L.HEAD_RUNS`, the subtitle `L.SUB_RUNS`;
    - the button text becomes `L.BTN_RUNS` ("Partidas" / "Runs").
- [ ] **Step 4:** `npm test` passes. Fix the old calendar tests deliberately: they read `B.rows` in the calendar view, so point them at `RV` the same way phase A's Home tests were moved.
- [ ] **Step 5:** commit `feat(groups): runs as cards, and a Create-run form inside Groups`.

### Task 2: The tray, the minimap count and the strip

**Files:**
- Create: `LevelMates/Tray.lua` (in the .toc after `Core.lua`'s dependents, before `Board.lua`).
- Modify:
  - `LevelMates/Core.lua`: `ns.Notice` adds to the tray; new `ns.NoticeAt(where, fmt, ...)`;
  - `LevelMates/MinimapButton.lua`: the count badge; Shift+click opens the tray;
  - `LevelMates/Settings.lua`: switch `stripNotices`, added to `S.QUIET_KEYS`;
  - callers: `Meetups.lua:27,39,243` → `"lfg"`; `Help.lua:85` → `"home"`; `LFG.lua:112,217,218` → `"lfg"`; `Questhub.lua:41,42` → `"lfg"`; `Gifts.lua` / `Wishlist.lua` → `"wishes"`; `Goals.lua` → `"goals"`;
  - the locales.
- Test: `tests/tray.test.lua`.

**Interfaces:**
- **Produces:**
  - `ns.Tray`: `T.Add(text, where)`, `T.List()` (newest first, at most 30, none older than 2 h; pruned on read), `T.Unread()`, `T.Open()`, `T.MarkRead()`, `T.frame`, `T.strip`.
  - Event `LM_TRAY_CHANGED`.
  - `T.STRIP_SECONDS = 10`, `T.STRIP_GRACE = 20`, `T.MAX = 30`, `T.KEEP = 7200`.
  - Storage: `ns.char.tray = { list = { {t, text, where} }, read = <time of last open> }`.
  - `ns.NoticeAt(where, fmt, ...)` is `ns.Notice` with a destination tab; plain `ns.Notice` has `where = nil` and no "Go" button.

- [ ] **Step 1: Write the failing test** `tests/tray.test.lua`:
  - **Tray contents:**
    - three notices → `T.List()` has 3, newest first, and `T.Unread() == 3`;
    - the minimap badge text is "3";
    - 35 notices → 30 kept;
    - an entry older than 2 h is gone (advance `time` via the stub).
  - **Opening:**
    - `T.Open()` shows the tray and sets `T.Unread() == 0` (the badge hides);
    - a tray row with `where = "lfg"` has a Go button that opens `B.ShowTab("lfg")`.
  - **Minimap:** Shift+click on the minimap button opens the tray (stub `IsShiftKeyDown`); a plain click still toggles the book.
  - **Strip:**
    - within 20 s of `PLAYER_ENTERING_WORLD`, no strip;
    - after that, a notice shows the strip with its text, hidden after 10 s;
    - in combat (`STUB.inCombat = true`, `InCombatLockdown`/`UnitAffectingCombat`), it waits; 5 notices in combat then `PLAYER_REGEN_ENABLED` → the strip shows only the newest;
    - quiet mode on → no strip, but the tray still records;
    - a click on the strip opens the tray.
  - `ns.Notice` still prints to chat as before.
- [ ] **Step 2:** run it and see it fail.
- [ ] **Step 3:** implement:
  - **Tray window:** a small `ns.Skin.Window` page (340×360, DIALOG strata, `UISpecialFrames`, clamped) with 12 rows of `time · text` plus a Go button, and a "Clear" button.
  - **Strip:** a Button under `Minimap` (`TOP`, `Minimap`, `BOTTOM`, 0, -18), 220×20, dark band, light `GameFontHighlightSmall` text, a 0.5 s fade at the end.
  - **Combat:** a pending flag, flushed on `PLAYER_REGEN_ENABLED`.
  - **Badge:** a FontString over the minimap button's corner (`GameFontNormalSmall`, white on a small dark circle using `Interface\\Minimap\\UI-Minimap-Background`), hidden at 0.
- [ ] **Step 4:** `npm test` passes; existing notice tests are untouched (chat output unchanged).
- [ ] **Step 5:** commit `feat(notices): a tray of the last notices, a count on the minimap button and a strip under the minimap`.

### Task 3: The level bar

**Files:**
- Create: `LevelMates/LevelBar.lua`.
- Modify: `LevelMates/Settings.lua` (switch `levelBar`, default false); the locales; the .toc.
- Test: `tests/level_bar.test.lua`.

**Interfaces:**
- **Produces:**
  - `ns.LevelBar`: `LB.Rate()` (XP per hour over the last 15 min, or nil without samples), `LB.TimeToLevel()` (seconds or nil), `LB.TimeInLevel()` (seconds), `LB.Kills()`, `LB.Toggle()`, `LB.frame`.
  - Storage: `ns.char.levelStart = { level, t, kills }`.
  - `LB.WINDOW = 900`.
- **Kill pattern:** built from the client's own string, never hard-coded English:

```lua
local function patternOf(fmt)   -- "%s dies, you gain %d experience." → "^(.+) dies, you gain (%d+) experience%.$"
	local p = fmt:gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1"):gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
	return "^" .. p .. "$"
end
LB.KILL = COMBATLOG_XPGAIN_FIRSTPERSON and patternOf(COMBATLOG_XPGAIN_FIRSTPERSON)
```

  - A `CHAT_MSG_COMBAT_XP_GAIN` message that matches `LB.KILL` counts as one kill. Quest XP uses another string (`COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED`) and does not count.
- **XP samples:** on `PLAYER_XP_UPDATE`, push `{GetTime(), gained}`, where gained = new XP minus last XP (with a level-up, add the rest of the old level: `lastMax - lastXP + newXP`). Drop samples older than `LB.WINDOW`. `Rate = sum * 3600 / max(60, now - oldest)`.

- [ ] **Step 1: Write the failing test** `tests/level_bar.test.lua`:
  - **XP rate:**
    - set `COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."`;
    - XP 0 → 100 → 300 over 10 min → `LB.Rate()` ≈ 1800/h (300 in 600 s);
    - `TimeToLevel` with max 1000 is (700 / 1800) h.
  - **Kills:** a matching kill message → `LB.Kills() == 1`; a quest XP line → still 1.
  - **Level-up:** `PLAYER_LEVEL_UP` → kills 0, `TimeInLevel` restarts, and the XP gained across the level counts in the rate.
  - **Empty state:** a fresh state with no samples → `Rate() == nil` and the text says "—" (no division by zero).
  - **Toggle:** off by default (`LB.frame` hidden or nil); `/lm barra` shows it, and a second time hides it and saves `settings.levelBar`.
  - **Locked:** the drag does nothing (`OnDragStart` does not call `StartMoving`).
  - **Reload:** after a simulated reload (`ns.char` kept), `TimeInLevel` continues from `levelStart.t`.
- [ ] **Step 2:** run it and see it fail.
- [ ] **Step 3:** implement:
  - **Bar:** a 260×34 frame on `UIParent` with a dark band, a 6 px XP bar with a rested overlay, and one line: `"Nv 24 · 45% (+12% desc.) · 1.8k XP/h · 23 min · 41 min en el nivel · 37 muertes"`.
  - **Placement:** saved in `ns.char.levelBarPos`; a right-click menu with Lock/Unlock and Hide.
  - **Updates:** at most once a second (`ns.Every("levelbar", 1)` only while shown).
- [ ] **Step 4:** `npm test` passes.
- [ ] **Step 5:** commit `feat(level): an optional level bar with XP per hour, time to level and kills`.

### Task 4: The level-up banner

**Files:**
- Create: `LevelMates/Ding.lua`.
- Modify: `LevelMates/Settings.lua` (switch `dingBanner`, in `QUIET_KEYS`); the locales; the .toc (after `LevelBar.lua`).
- Test: `tests/ding.test.lua`.

**Interfaces:**
- **Produces:** `ns.Ding`: `DG.Show(level)`, `DG.frame`, `DG.SECONDS = 8`, and `DG.Rank(level)`, the place in the guild race: 1 + the number of guild members (`ns.Members.List()`) with a higher level, or nil when the member list is empty.
- **Consumes:** `ns.LevelBar.TimeInLevel()` before its reset (Ding listens to `PLAYER_LEVEL_UP` and reads the bar's pre-reset value through `LB.lastLevelTime`, set by the bar at the level-up), `LB.Rate()`, `ns.Members.List()`.

- [ ] **Step 1: Write the failing test** `tests/ding.test.lua`:
  - **On level-up:** `PLAYER_LEVEL_UP(24)` shows the banner with "¡Nivel 24!" (`L.DING_TITLE`), the time it took and the XP per hour.
  - **Rank:** with `STUB.memberInfo` holding 2 members above 24 and 1 below, the rank line says 3.
  - **Timing:** hidden after 8 s; a click closes it at once.
  - **Two levels in a row:** the second replaces the first; there is one frame and it hides 8 s after the second.
  - **In combat:** it still shows; the banner is not protected.
  - **Quiet mode:** `dingBanner` off → nothing shows.
  - **Nothing to chat:** `#STUB.sent` unchanged, and `STUB.lastChat` nil.
- [ ] **Step 2:** run it and see it fail.
- [ ] **Step 3:** implement:
  - a centred 360×110 frame (strata HIGH, the game's `Interface\\LevelUp\\LevelUpTex` when the client has it, else a dark band with a gold divider);
  - the title in `GameFontNormalHuge` (Morpheus via `Fonts\\MORPHEUS.TTF` when it loads), with three small lines below;
  - a 0.3 s fade in and a 0.5 s fade out, stamp-guarded like the feedback line.
- [ ] **Step 4:** `npm test` passes.
- [ ] **Step 5:** commit `feat(level): a banner when you level up: the time it took, XP per hour, your place in the race`.

### Task 5: Docs and build

- **Docs:**
  - CHANGELOG: four bullets under 0.4.0, about the runs and form, the tray/strip/count, the level bar and the banner;
  - README in both languages: Groups (Runs and the form), Help and notices (tray and strip), commands (`/lm barra`, `/lm bar`).
- **Build:** run `npm test`, then copy to AddOns (`rm -rf` then `cp -r`).
- **Commit:** `docs: runs, tray, level bar and banner in the 0.4.0 notes`.
