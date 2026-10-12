# Guild Members, History, Race and Bank Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Members sub-tab (list with shared notes, our own MOTD, roster history, alts tree, race to 60) and a Bank sub-tab (a snapshot read by whoever opens the guild bank, shared with everyone).

**Architecture:**
- **New `GuildNotes.lua`:** board records `gn` and `gmo`, with officer checks done on the receiver.
- **New `GuildHistory.lua`:** a local roster diff with guards, plus race-to-60 tracking.
- **New `GuildBank.lua`:** a debounced read and a board record `gbk` (blob).
- **New `Members.lua`:** the list, alts tree and race rows for the board.
- **Board:** two new Guild sub-tabs, narrower sub-tab buttons, and the MOTD on Home.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.1); node + fengari tests.

**Spec:** `docs/superpowers/specs/2026-10-12-levelmates-guild-design.md`

## Global Constraints

- **Records:**
  - `gn`: id `NameKey(f)`, fields `f` (48) and `n` (0–120; an empty text deletes);
  - `gmo`: id `motd`, field `n` (180);
  - `gbk`: id `bank`, fields `t`, `m` and `p` (long, sent as a blob).
- **Permissions on receive:** another's note or the MOTD only from an officer (`R.IsOfficer(sender)`). On send: mine always; others' or the MOTD only if `CanEditPublicNote()` / `CanEditMOTD()` (true when the call is missing, so the receivers decide).
- **History:**
  - debounce 2 s after `GUILD_ROSTER_UPDATE`;
  - the first read only records a baseline;
  - a partial read (fewer rows than `GetNumGuildMembers()`) produces no leaves;
  - a mass shrink (more than 5 and more than half) waits for confirmation;
  - keep 500 entries;
  - joins and leaves also go to the wall (locally).
- **Race:**
  - a level-60 arrival seen live (my heartbeat-known mate or the roster changing while I am online) is "first";
  - mates already at 60 at the baseline count as "already there";
  - first overall and first per class;
  - wall entry and notice.
- **Bank:**
  - on `GUILDBANKFRAME_OPENED` (or the player-interaction show for the guild banker), query the viewable tabs 0.4 s apart and read them after 1.2 s of quiet;
  - an unloaded tab keeps the previous contents;
  - on close, `S.Put("gbk", "bank", …)` if the option `shareBank` is on;
  - reject `t` more than 300 s in the future.
- **UI:** Guild sub-tab buttons 76 px wide (8 of them fit).
- **Policy:** whisper and invite from clicks. Lua 5.1. Ask before pushing or tagging.

## Review Focus

1. A note written by a non-officer about someone else must be rejected by everyone, including the catch-up relay.
2. A partial roster right after login: no false "left" entries.
3. Bank tabs the player cannot view: skipped, never wiped.
4. A guild of 500 members: the list view pages, and the scan stays cheap (no per-redraw full rebuild).
5. A member with a surname in notes, history and race.

---

### Task 1: Notes and MOTD (`GuildNotes.lua`)

**Files:**
- Create: `LevelMates/GuildNotes.lua`
- Test: `tests/guild_notes.test.lua`, `tests/guild_notes_sync.net.mjs`

**Interfaces:**
- Produces:
  - `GN.Note(name) → text, writer, at`;
  - `GN.SetNote(name, text) → bool`;
  - `GN.CanWrite(name)`;
  - `GN.Motd() → text, writer, at`;
  - `GN.SetMotd(text)`;
  - event `LM_GUILDNOTES_CHANGED`.

- [ ] **Step 1: failing tests.**
  - **Unit:**
    - my own note is stored and sent;
    - Mario (not an officer) writing Ana's note is rejected;
    - Luis (an officer, `STUB.guildRoles.Luis = 2`) writing it is accepted;
    - an empty text deletes;
    - the MOTD from a non-officer is rejected and from an officer accepted;
    - the MOTD is shown on Home (Task 4 checks the UI).
  - **Net:** officer Ana sets the MOTD and leaves; Cris logs in and reads it.
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass and `npm test`. **Step 5:** commit `feat(guild): shared notes and our own message of the day`.

### Task 2: History and race (`GuildHistory.lua`)

**Files:**
- Create: `LevelMates/GuildHistory.lua`
- Stub: `C_Club.GetMemberInfo` gains `level`, `guildRankOrder` and `presence` from `STUB.memberInfo[name]`
- Test: `tests/guild_history.test.lua`

**Interfaces:**
- Produces:
  - `GH.List() → { { k = "join"|"leave"|"rankup"|"rankdown"|"level", who, a, t } }`, newest first;
  - `GH.KnownSince(name)`;
  - `GH.Race() → { { name, level, class, at, first = bool, firstClass = bool, before = bool } }`;
  - `GH.Scan()`.

- [ ] **Step 1: failing test.**
  - The first scan has no entries.
  - Add Pepe → "join"; remove Pepe → "leave".
  - Change Mario's rank order from 4 to 3 → "rankup".
  - A partial read (`STUB.guildTotal` greater than the rows) gives no leave.
  - 10 of 12 vanish → nothing until a second identical read, then 10 leaves.
  - The race: Mario at 60 in the baseline → `before`. Ana goes 59→60 while I am online → first, and first of her class. Then Luis, a different class, 59→60 → first of his class, not first overall.
  - The join goes to the wall.
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass and `npm test`. **Step 5:** commit `feat(guild): roster history and the race to 60`.

### Task 3: Bank (`GuildBank.lua`)

**Files:**
- Create: `LevelMates/GuildBank.lua`
- Stub: `GetNumGuildBankTabs`, `GetGuildBankTabInfo`, `QueryGuildBankTab`, `GetGuildBankItemLink`, `GetGuildBankItemInfo` and `GetGuildBankMoney` from `STUB.bank`
- Test: `tests/guild_bank.test.lua`, `tests/guild_bank_sync.net.mjs`

**Interfaces:**
- Produces:
  - `GB.Snapshot() → { t, m, by, tabs = { { name, items = { [id] = n } } } }`;
  - `GB.Rows(search) → { { id, n, tab } }`;
  - `GB.Encode(tabs)` and `GB.Decode(p)`.

- [ ] **Step 1: failing tests.**
  - **Unit:**
    - with two tabs (one not viewable), open → advance → the snapshot has one tab, stacks summed and money;
    - close → `gbk` sent (blob);
    - encode/decode round trip with names that contain `~,|`;
    - a received snapshot from 10 min in the future is rejected;
    - `shareBank` off → nothing sent.
  - **Net:** Ana opens and closes the bank and leaves; Cris logs in and `GB.Rows()` has the items.
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass and `npm test`. **Step 5:** commit `feat(guild): the guild bank, read by whoever opens it and shared`.

### Task 4: Members and Bank sub-tabs; MOTD on Home

**Files:**
- Create: `LevelMates/Members.lua` (`MB.List(filter, search)`, `MB.Alts()`, `MB.RaceRows()`)
- Modify: `Board.lua` (GUILD_KEYS + "members", "bank"; 76 px sub buttons; views and filters; row menus with "Write note" via a StaticPopup; Fill functions), `Home.lua` (a MOTD row at the top), Settings (`shareBank`)
- Locales
- Test: `tests/guild_ui.test.lua`

- [ ] **Step 1: failing test.**
  - The Guild tab shows 8 sub buttons, each 76 px wide, with no overlap: x + width of one ≤ x of the next.
  - Members:
    - the list shows all roster members with their notes;
    - the filter cycles;
    - a row's menu has Whisper / Invite / Write note (mine);
    - the views Historial / Alts / Carrera show `historyEntry` / `altEntry` / `raceEntry` rows.
  - Bank: rows with item links and the "seen by … ago" heading.
  - Home: the first section shows the MOTD.
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass and `npm test`. **Step 5:** commit `feat(guild): Members and Bank sub-tabs; the message of the day on Home`.

### Task 5: Docs and build

- CHANGELOG 0.4.0 bullets; README features and privacy (your shared note, the bank snapshot when you open it, with the switch) in both languages.
- `npm test`; copy to AddOns.
- Commit `docs: guild members and bank in the 0.4.0 notes`.

---

## Self-review notes

- **Spec coverage:**
  - §1.1 and §1.4–1.5: Tasks 2 and 4;
  - §1.2: Task 1;
  - §1.3: Task 2;
  - §2: Task 3;
  - §3: Tasks 1 and 3;
  - §5: each task's tests.
- **Interfaces:**
  - GN is used by Task 4 (notes in rows, the MOTD on Home);
  - GH by Task 4 (Historial and Carrera);
  - GB by Task 4 (Bank).
