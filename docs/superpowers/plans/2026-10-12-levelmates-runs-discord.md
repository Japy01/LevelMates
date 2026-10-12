# Runs, Roles, Suggested Groups and Discord Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn meetups into 5-slot runs with leader authority, add shared preferred roles, the "Together" group suggestions, "Invite all", and Discord announcements through WoW Forever's guild↔Discord link.

**Architecture:**
- **Records:** everything rides the sync layer from project 1. Runs stay `qd`/`qj` records with two new fields (`r` = the leader's role, `dc` = announce in Discord), plus a new board record `qm` (the leader's official line-up).
- **New files:**
  - `Roles.lua`: preferred role (personal state `rol`, via `Sync.Personal`) and class guesses.
  - `Together.lua`: computes suggestions locally.
  - `Discord.lua`: checks availability, builds lines and posts them from clicks, holding blocked lines for a "Send to Discord" button.
- **UI changes:** the meetup dialog, the dungeon panel, the Groups tab and the cards.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.1); tests in node + fengari (`npm test`, `node tools/run-lua-test.mjs LevelMates tests/X.test.lua`, multi-client `tests/*.net.mjs` with `tools/lua-net.mjs`).

**Spec:** `docs/superpowers/specs/2026-10-12-levelmates-runs-discord-design.md` (builds on `2026-10-12-levelmates-sync-v2-design.md`).

## Global Constraints

- **Slots:** 1 T, 1 H, 3 D. The leader holds one slot from creation.
- **`qm` (official line-up):** field `m` holds "T=Name,H=Name,D=Name,…" in at most 200 chars. Full names, spaces included. Only the run's owner may publish it (`idOwner`/`may`).
- **Discord availability:** `C_Discord.IsEnabled()`, `IsGuildChannelLinked()` and `IsUserOAuthed()`, each in pcall. Unknown counts as no.
- **Discord sending:**
  - `SendChatMessage(line, "GUILD_DISCORD")`, only inside a click handler; never an automatic retry.
  - At most 236 chars, `|` removed, no item links.
  - If chat is blocked, hold the latest line per run and show a "Send to Discord" button.
- **Roles:**
  - Class guesses: tank = WARRIOR, DRUID, PALADIN; healer = PRIEST, DRUID, SHAMAN, PALADIN.
  - First-role guess: WARRIOR→T, DRUID→T, PALADIN→T, PRIEST→H, SHAMAN→H; everyone else D.
- **Together:**
  - Candidates: online guildmates plus me, with level from `min` to `max + 2`, and at least 2 per dungeon.
  - At most 5 suggestions, sorted by filled slots, then number of candidates, then the higher dungeon.
  - Nothing is sent.
- **Policy:** nothing posts to chat, invites or whispers without a click. Lua 5.1 only; no other addons' files.
- **Release:** ask the user before pushing or tagging.

## Review Focus

1. A leader with a surname ("Name Surname") and members with surnames: `qm` parsing, invite targets and Discord lines must keep the full names.
2. A run whose leader is offline: joins stay "unconfirmed" and are never shown as placed, and nobody else can publish `qm`.
3. Two joins for the last slot arriving at the leader in the same instant: exactly one is placed; the other is waiting, for everyone.
4. Discord lines with notes that contain `|`, `%`, accents or 40 characters: they stay under 236 and are readable.
5. `ADDON_ACTION_BLOCKED` right after a Discord send: the line is marked unsent and the button returns, with no error spam.

---

### Task 1: Preferred roles (`Roles.lua`)

**Files:**
- Create: `LevelMates/Roles.lua` (`.toc` after `Sync.lua`)
- Locales: `ROLE_PICK`, `ROLE_GUESS`
- Test: `tests/roles.test.lua`

**Interfaces:**
- Produces:
  - `ns.Roles.Of(name)` returns `role, guessed`. The role is `"T"|"H"|"D"`; `guessed` is true when the role comes from the class.
  - `ns.Roles.Can(class, role)` → bool.
  - `ns.Roles.Guess(class)` → role.
  - `ns.Roles.Mine()` returns the role or nil.
  - `ns.Roles.Set(role)`.
  - Event `LM_ROLES_CHANGED`.
  - Wire: personal kind `rol { r = oneOf("T","H","D") }`, via `ns.Sync.Personal`, stored per guild in `ns.db.roles[guild][name] = { r, t }`.

- [ ] **Step 1: failing test**

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local RO, C = ns.Roles, ns.Comm
assert(RO.Guess("WARRIOR") == "T" and RO.Guess("PRIEST") == "H" and RO.Guess("MAGE") == "D", "guesses")
assert(RO.Can("DRUID", "H") and RO.Can("PALADIN", "T") and not RO.Can("MAGE", "T"), "who can")
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412, c = "PRIEST" }), "GUILD", "Mario-Testrealm")
local r, g = RO.Of("Mario"); assert(r == "H" and g, "Mario guessed healer")
STUB.Receive("LVLM2", C.Encode("rol", { r = "D" }), "GUILD", "Mario-Testrealm")
r, g = RO.Of("Mario"); assert(r == "D" and not g, "Mario chose damage")
local n = #STUB.sent
RO.Set("T"); STUB.Advance(2)
local sent; for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "rol" then sent = f.r end end
assert(sent == "T" and RO.Mine() == "T" and (RO.Of(ns.Me())) == "T", "mine chosen and shared")
```

- [ ] **Step 2:** run it and watch it fail (`ns.Roles` nil).
- [ ] **Step 3:** implement as in the Interfaces block. The schema goes through `C.SCHEMA.rol` / `C.REQUIRED.rol`. `Set` stores `ns.char.role` and calls the personal helper's `Mark("urgent")`. Receiving stores the role and fires the event.
- [ ] **Step 4:** test passes; `npm test` green.
- [ ] **Step 5:** commit `feat(roles): a preferred role, shared; guessed from the class when unset`.

### Task 2: Runs with slots and the leader's line-up

**Files:**
- Modify: `LevelMates/Meetups.lua`
- Test: `tests/runs.test.lua`, `tests/runs_sync.net.mjs`; adapt `tests/meetups.test.lua`

**Interfaces:**
- Consumes: `ns.Roles` (Task 1), `ns.Sync`.
- Produces:
  - `M.Create(d, at, note, role, discord)`.
  - `M.Slots(m)` returns `{ T = {names}, H = {names}, D = {names} }` from `qm` when present, else from the leader and joins. Also returns `confirmed` (bool) and `waiting` (names).
  - `M.Free(m, role)` → bool.
  - `M.IsFull(m)` → bool.
  - `M.AddMember(id, name, role)` and `M.RemoveMember(id, name)`, for the leader only.
  - The list view gains `role` (the leader's), `dc` and `slots`.
  - Record `qm { m }`, a board record, id = the run's id, `idOwner = function(id, owner) local r = S.Get("qd", id); return r ~= nil and r.o == owner end`.

**Leader placement:** when the leader's client sees a join (`qj` change, any how except expired) for one of its runs, it recomputes the line-up:
- keep the current members whose join still exists (or who were added by hand);
- add new joins in rev order while their role has room;
- if the line-up changed, call `S.Put("qm", id, { m = … })`.

A leaver's tombstone removes them.

- [ ] **Step 1: failing unit test**

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local M, C, S = ns.Meetups, ns.Comm, ns.Sync
for _, n in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", n .. "-Testrealm") end
assert(M.Create(5, M.Now() + 60, "", "T", false), "created as tank")
local m = M.List(5)[1]
local s = M.Slots(m)
assert(s.T[1] == "Tester" and #s.D == 0 and not M.Free(m, "T") and M.Free(m, "D"), "the leader holds the tank slot")
local function join(id, who, role) STUB.Receive("LVLM2", C.Encode("qj", STUB.Rec{ id = id .. "." .. ns.NameKey(who), r = role }), "GUILD", who .. "-Testrealm") end
join(m.id, "Mario", "H"); join(m.id, "Ana", "H")
STUB.Advance(1)
m = M.List(5)[1]; s = M.Slots(m)
assert(s.H[1] == "Mario" and s.waiting[1] == "Ana", "first come, the second waits")
local qm; for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == "qm" then qm = f.m; break end end
assert(qm and qm:find("H=Mario", 1, true) and qm:find("T=Tester", 1, true), "line-up published: " .. tostring(qm))
assert(M.AddMember(m.id, "Luis", "D") and M.Slots(M.List(5)[1]).D[1] == "Luis", "added by hand")
assert(not M.AddMember(m.id, "Ana", "T"), "a full role refused")
assert(M.RemoveMember(m.id, "Luis") and #M.Slots(M.List(5)[1]).D == 0, "removed")
-- someone else's qm for my run is ignored
STUB.Receive("LVLM2", C.Encode("qm", STUB.Rec{ id = m.id, m = "T=Ana" }), "GUILD", "Ana-Testrealm")
assert(M.Slots(M.List(5)[1]).T[1] == "Tester", "only the leader's line-up counts")
```

- [ ] **Step 2: failing net test** (`tests/runs_sync.net.mjs`)

The leader Ana creates a run as tank and stays. Ben and Dani join as H in the same step. Then Ana leaves, Cris logs in, and Cris sees:
- `T=Ana`;
- exactly one of Ben or Dani in H;
- the other waiting;
- the run confirmed.

```js
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris', 'Dani']);
net.leave('Cris'); net.advance(5);
net.run('Ana', 'local _, ns = ...; ns.Meetups.Create(5, ns.Meetups.Now() + 60, "", "T", false)');
net.advance(3);
net.run('Ben', 'local _, ns = ...; ns.Meetups.Join(ns.Meetups.List()[1].id, "H")');
net.run('Dani', 'local _, ns = ...; ns.Meetups.Join(ns.Meetups.List()[1].id, "H")');
net.advance(6);
net.leave('Ana'); net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(20);
const got = net.run('Cris', 'local _, ns = ...; local m = ns.Meetups.List()[1]; local s = ns.Meetups.Slots(m); return (s.T[1] or "-") .. "|" .. (s.H[1] or "-") .. "|" .. (s.waiting[1] or "-") .. "|" .. tostring(s.confirmed)');
const [t, h, w, c] = got.split('|');
if (t !== 'Ana' || !['Ben', 'Dani'].includes(h) || !['Ben', 'Dani'].includes(w) || h === w || c !== 'true') { console.error('Cris sees:', got); process.exit(1); }
console.log('ok tests/runs_sync.net.mjs');
```

- [ ] **Step 3: implement**
  - `qd` gains `r = oneOf(T,H,D)` and `dc = int(0,1)`. Create stores them; the role defaults to `ns.Roles.Mine() or ns.Roles.Guess(myClass)`.
  - The `qm` type: `onChange` → `changed()`.
  - `M.Slots`:
    - if `S.Get("qm", id)`, parse `m` with the pattern `([THD])=([^,]+)` → confirmed;
    - else the leader in `rec.d.r`, plus joins in rev order while room, all with `confirmed = false`;
    - waiting = joins not placed.
  - `M.Join` refuses a role that is not free.
  - `M.Leave` as today.
  - The leader's placement listener runs on `qj` changes for runs I own.
  - Migration from the meetups that sync-v2 stored: a `qd` without `r` counts as the guess of the leader's class (`R.mates[by].class`, or "D" when unknown).
- [ ] **Step 4:** both tests pass; adapt `tests/meetups.test.lua` (the `Create` signature keeps working without role and discord); run `npm test`.
- [ ] **Step 5:** commit `feat(runs): five slots, the leader's line-up, waiting list, add and remove by hand`.

### Task 3: Invite all

**Files:**
- Modify: `LevelMates/Board.lua` (`B.InviteAll(names)`)
- Test: `tests/invite_all.test.lua`

**Interfaces:**
- Produces: `B.InviteAll(names)` → `invited, offline` (counts). It:
  - calls `C_PartyInfo.InviteUnit` for each online name (`R.mates[name]`), skipping me and duplicates;
  - prints `L.INVITE_ALL` once ("Invited %d: %s. Not online: %s").

- [ ] **Step 1: failing test**

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B = ns.Comm, ns.Board
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Mario Rossi-Testrealm")
local invited = {}
C_PartyInfo.InviteUnit = function(n) invited[#invited + 1] = n end
local before = #STUB.printed
local a, off = B.InviteAll({ "Mario Rossi", "Ana", ns.Me(), "Mario Rossi" })
assert(a == 1 and off == 1 and invited[1] == "Mario Rossi" and #invited == 1, "online only, once, never me")
assert(#STUB.printed == before + 1, "one summary line")
```

- [ ] **Step 2:** watch it fail. **Step 3:** implement. **Step 4:** pass and `npm test`. **Step 5:** commit `feat(groups): invite all, one summary line`.

### Task 4: Together (`Together.lua`)

**Files:**
- Create: `LevelMates/Together.lua` (`.toc` after `Roles.lua` and `Dungeons.lua`)
- Test: `tests/together.test.lua`

**Interfaces:**
- Produces: `ns.Together.Suggest()` returns a list of at most 5 suggestions `{ d = dungeonId, rows = { { role, name, level, guessed } … }, filled = n, candidates = n }`.

- [ ] **Step 1: failing test.** Set up mates:
  - Mario 20 PRIEST, with chosen role H;
  - Ana 21 WARRIOR, no role (so guessed T);
  - Luis 19 MAGE;
  - me at level 20.

  Then:

```lua
local sug = ns.Together.Suggest()
local dm
for _, s in ipairs(sug) do if s.d == 5 then dm = s end end   -- Deadmines 17-26
assert(dm and dm.filled == 4 and dm.candidates == 4, "four of us fit")
local byRole = {}
for _, r in ipairs(dm.rows) do byRole[r.role] = byRole[r.role] or r end
assert(byRole.H.name == "Mario" and not byRole.H.guessed and byRole.T.name == "Ana" and byRole.T.guessed, "chosen first, then guessed")
assert(#sug <= 5, "at most five")
```

  Also check that a dungeon with only one fitting member gives no suggestion (for example Gnomeregan 29-38, with nobody above 21).
- [ ] **Step 2:** watch it fail. **Step 3:** implement the Global Constraints algorithm. **Step 4:** pass and `npm test`. **Step 5:** commit `feat(together): suggested groups from who is online, by level and role`.

### Task 5: Discord (`Discord.lua`)

**Files:**
- Create: `LevelMates/Discord.lua` (`.toc` after `Meetups.lua`)
- Modify: `Meetups.lua` (call `ns.Discord.Run(kind, m, who, role)` from `Create`, `Join`, `Leave`, `Cancel`, `AddMember`, `RemoveMember` when `m.dc`)
- Stub: `C_Discord`, a `SendChatMessage` capture for `GUILD_DISCORD`, and `ADDON_ACTION_BLOCKED`
- Test: `tests/discord.test.lua`

**Interfaces:**
- Produces:
  - `DC.Available()` returns `ok, whyKey`, where the key is `"DISCORD_NO_GUILD"`, `"DISCORD_NO_USER"` or nil.
  - `DC.Line(kind, m, who, role)` → string of at most 236 chars. The kind is `"new"`, `"join"`, `"leave"`, `"cancel"`, `"add"` or `"remove"`.
  - `DC.Run(kind, m, who, role)` posts now if it can, else holds; it returns `"sent"`, `"held"` or `"off"`.
  - `DC.Held(runId)` → line or nil.
  - `DC.SendHeld(runId)` (from a click).
  - Event `LM_DISCORD_CHANGED`.

- [ ] **Step 1: failing test**

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local DC, M = ns.Discord, ns.Meetups
local posted = {}
SendChatMessage = function(text, chatType) posted[#posted + 1] = { text, chatType } end
C_Discord = { IsEnabled = function() return true end, IsGuildChannelLinked = function() return true end, IsUserOAuthed = function() return false end }
assert(select(2, DC.Available()) == "DISCORD_NO_USER", "not linked: why")
C_Discord.IsUserOAuthed = function() return true end
assert(DC.Available(), "available")
assert(M.Create(5, M.Now() + 60, "traed | pociones %", "T", true), "created with Discord")
assert(#posted == 1 and posted[1][2] == "GUILD_DISCORD" and #posted[1][1] <= 236 and not posted[1][1]:find("|", 1, true), "one line, clean: " .. tostring(posted[1] and posted[1][1]))
assert(posted[1][1]:find(ns.Dungeons.Name(5), 1, true), "names the dungeon")
-- a run without the mark posts nothing
M.Create(6, M.Now() + 90, "", "D", false)
assert(#posted == 1, "no mark, no line")
-- chat blocked: held, the latest per run, never sent on its own
local id = M.List(5)[1].id
C_ChatInfo.InChatMessagingLockdown = function() return true end
M.Cancel(id)
assert(DC.Held(id) and #posted == 1, "held")
STUB.Advance(120); assert(#posted == 1, "no automatic retry")
C_ChatInfo.InChatMessagingLockdown = function() return false end
DC.SendHeld(id)
assert(#posted == 2 and not DC.Held(id), "sent from the click")
-- blocked right after a send: marked unsent, the button back
local m2 = M.List(6)[1]
STUB.Fire("ADDON_ACTION_BLOCKED", "LevelMates", "SendChatMessage")
```

  The stub's `C_ChatInfo.InChatMessagingLockdown` reads `STUB.lockdown`; the test overrides it directly. Also check the line at 40-char notes with accents (less than or equal to 236) and a surnamed leader (the full name in the line).
- [ ] **Step 2:** watch it fail. **Step 3:** implement:
  - The line format follows spec section 4.
  - Lock check: `C_ChatInfo.InChatMessagingLockdown()`, or a block in the last 30 s.
  - During `SendChatMessage` set a "sending" flag; an `ADDON_ACTION_BLOCKED` naming LevelMates while it is set marks the line held and starts the 30 s cooldown.
  - Calls from `Meetups.lua` happen only inside the click paths (Create, Join, Leave, Cancel, AddMember, RemoveMember), never from receive handlers.
- [ ] **Step 4:** pass and `npm test`. **Step 5:** commit `feat(discord): runs announced in the guild's Discord channel, from clicks only`.

### Task 6: Interface

**Files:**
- `MeetDialog.lua`: role buttons and a Discord checkbox with its reason, plus "Copy for Discord" when unavailable.
- `DungeonPanel.lua`: slot rows, waiting rows, and leader buttons (Invite all, Add…, Remove, Send to Discord).
- `Board.lua`:
  - the Groups tab: a "My role" line and a "Together" view button next to Calendar;
  - the card badge "hh:mm · n/5".
- `MateCard.lua`: role line.
- `Settings.lua`: role dropdown under General.
- Locales: all new strings, enUS and esES.
- Test: `tests/runs_ui.test.lua`

- [ ] **Step 1: failing test**, which checks:
  - the dialog has `Dlg.roleButtons.T/H/D` and `Dlg.discord`;
  - with Discord unavailable, `Dlg.discord.enabled == false` and `Dlg.copy:IsShown()`;
  - `DP.Rows(5)` for my run contains `kind = "slot"` rows (5 of them) and a `kind = "leader"` row with Invite all;
  - `B.ShowTab("lfg")` shows `B.roleLine` and `B.togetherButton`;
  - after a click on Together, the rows carry `togetherEntry`;
  - the card badge text ends with "/5".
- [ ] **Step 2:** watch it fail. **Step 3:** implement (ink, book look and button templates as in the existing windows). **Step 4:** pass and `npm test`. **Step 5:** commit `feat(ui): runs with slots in the panel, my role, Together, Discord in the dialog`.

### Task 7: Docs and build

- CHANGELOG 0.4.0 gains these bullets:
  - runs with 5 slots and leader authority, waiting list, invite all;
  - preferred role;
  - Together;
  - Discord, including what each player and the guild master must link.
- README in both languages:
  - features;
  - privacy (your preferred role is shared);
  - policy (Discord lines only from your clicks).
- `npm test` green; copy to AddOns (plain copy).
- Commit `docs: runs, roles, Together and Discord in the 0.4.0 notes`.

---

## Self-review notes

- **Spec coverage:**
  - §1 (slots, leader authority, by hand, invite all, lifetime): Tasks 2 and 3;
  - §2: Task 1;
  - §3: Task 4;
  - §4: Task 5;
  - §5 (wire): Tasks 1, 2 and 5;
  - §6: Task 6;
  - §7: the tests of each task;
  - migration: Task 2.
- **Interfaces:**
  - `M.Create(d, at, note, role, discord)` is used by the dialog in Task 6 and by the tests;
  - `ns.Roles.Of/Guess/Can` are used by Tasks 2, 4 and 6;
  - `B.InviteAll` is used by Tasks 4 and 6 (the Together button and the panel);
  - `DC.Run` is called only from Meetups click paths.
