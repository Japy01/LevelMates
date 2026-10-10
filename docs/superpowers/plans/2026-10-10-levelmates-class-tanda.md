# Chat ads, guildmate card and Class tab — Implementation Plan

> **For agentic workers:** executed inline (superpowers:executing-plans), TDD per task, one final review.

**Goal:** dungeon cards also count group ads read from public chat; a left click on a guildmate opens their card; a new "Class" tab lists guild talent builds of my class, a macro library per class and macros shared by guildmates.

**Architecture:** three new data modules (`ChatAds.lua`, `Builds.lua`, `Macros.lua`) plus a window (`MateCard.lua`); Board gets the ninth tab, wider window and a few hooks. New addon kinds `tb`, `mc`, `mcx` in `Comm.lua`.

**Tech stack:** Lua 5.1 (WoW Forever 1.60, interface 16001), tests on node + fengari with `tools/wow-stub.lua`.

**Spec:** `docs/superpowers/specs/2026-10-10-levelmates-class-tanda-design.md`

## Global Constraints

- Nothing posts to chat, invites, whispers or opens game windows without a click.
- Addon messages to the guild only; only roster mates are believed; ≤ 255 bytes per message.
- No reading of chat text that the game marks secret (`issecretvalue`).
- Both locales get every new string; Spanish is the user's language.
- Window 680 wide; every column set still sums to the same total, which must fit.

## Review Focus

1. Chat ad in a channel the addon itself uses (the hidden `LM…` channel) must not count — test in ChatAds.
2. A chat word that merely contains an alias ("mines" vs "dm" inside "admin") must not match — whole words only; test.
3. A build message from someone of another class must not appear in my list — test.
4. Creating a macro when a macro of that name exists or there is no character slot, or in combat — tests.
5. A shared macro body with a newline must survive the wire; with "|" it is refused — tests.

## Tasks

### Task 1: wider window and the Class tab plumbing
- `Board.lua`: `B.WIDTH = 680`; each column set gains 80 in its widest text column; `TAB_KEYS` adds `"class"` after `"crafts"`; `TAB_LABELS.class = "TAB_CLASS"`, `HEAD_KEY.class = "CLASS"`; `PAGE_KEY.class = "classPage"`.
- Locales: `TAB_CLASS`, `HEAD_CLASS`, `SUB_CLASS`, `SEARCH_CLASS`.
- Tests: `board_journal.test.lua` expects 680; new `board_class.test.lua` shows the tab exists and the window is 680.

### Task 2: ChatAds.lua
- `CA.Parse(text) -> dungeonId|nil`: normalise (lower case, strip Spanish accents, non-alphanumerics to spaces), whole-word alias match (multi-word aliases allowed) and at least one group word.
- `CA.Hear(text, sender, channelBaseName)`: ignores secret values, my own name, the hidden addon channel (`^LM%x%x%x%x%x%x%x%x$`), the option `readChatAds`; one ad per sender (newest), 10 minutes.
- `CA.For(id) -> { {name, text, t}, ... }` newest first, expired pruned.
- Event `CHAT_MSG_CHANNEL`; fires `LM_LFG_CHANGED` on change.
- Board: card count "2 buscan · 3 en el chat"; tooltip lines; menu "Susurrar a X (chat)"; search matches chat names.
- Option `readChatAds` (default on) in Settings and DEFAULTS.

### Task 3: Builds.lua (kind `tb`)
- `BU.Mine()`: `{ c, s, l, p = "gid:spent,...", b = code|nil }` from C_Traits (pcall everywhere; nil when the client has no tree).
- Export code: `PlayerSpellsFrame.TalentsFrame:GetLoadoutExportString()` in pcall.
- Sent on `LM_ANNOUNCED`, `LM_PING_ANSWERED`, `TRAIT_CONFIG_UPDATED` / `PLAYER_LEVEL_UP` (debounced 5 s), on talents frame hide; LATEST_ONLY; pending on drop; option `shareBuild` (default on; off sends `tb` without p/b → withdraw).
- `BU.List()`: mine first, then guildmates of my class (30 days), by level desc.
- `BU.PointsText(e)`: branch names from my own tree (same class), "Name 9 / Name 0".
- `BU.Open(e)`: `SetItemRef("talentbuild:s:l:b", link, "LeftButton")` in pcall — click only.

### Task 4: Macros.lua (library, kinds `mc`, `mcx`)
- `MA.LIBRARY[class] = { {key, name, body = "...{s:ID}..."}, ... }`; `MA.Library(class)` resolves names via `C_Spell.GetSpellName`, skipping macros with an unknown spell.
- `MA.Create(name, body)`: refuses in combat (`InCombatLockdown`), when the name exists (`GetMacroIndexByName`), or when character macros are full (`GetNumMacros` vs `MAX_CHARACTER_MACROS` or 30); else `CreateMacro(name, 134400, body, true)` and a notice.
- Sharing: `MA.Share(name)` (max 5, reads `GetMacroInfo(GetMacroIndexByName(name))`, refuses "|" or too long), `MA.Unshare(name)`; `mc` { n, x }, `mcx` { n }; resent on announce/ping; pending on drop.
- `MA.Guild()`: shared macros of guildmates of my class (30 days).

### Task 5: Class tab on the board
- Rows: section headers (Builds / Macro library / Guild macros) and entries; paged.
- Click on an entry opens a menu: build → "Ver build" (if code), "Susurrar"; library → "Crear macro"; guild macro → "Crear macro", "Susurrar"; tooltip shows the body.
- Bottom left "Compartir macro": menu with my macros (shared ones checked → unshare).

### Task 6: MateCard.lua
- `MC.Lines(name) -> { text, ... }` and `MC.Show(name)`; `LM_ROW_CLICK` opens it. Buttons Whisper / Invite / Waypoint / View build.

### Task 7: sim, docs
- `/lm sim clase` adds sample builds, guild macros and a chat ad; `/lm sim off` clears them.
- README (en/es), CHANGELOG 0.2.0, toc notes.
