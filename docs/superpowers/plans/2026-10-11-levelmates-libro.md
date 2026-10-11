# El libro de la hermandad — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline, as the previous batches). Steps use checkbox (`- [ ]`) syntax.

**Goal:** LevelMates becomes a guild book: five tabs (Home, Guildmates, Dungeons, Guild with sub-sections, Journal), a Home page that says what to do now, guild progress (points, guild level, weekly challenge, soft weekly rankings) and the spellbook's parchment look.

**Architecture:** a new data module `Points.lua` (kind `pt`) and a data module `Home.lua` (pure functions building the Home rows). The board keeps its content keys (`mates`, `lfg`, `feed`, `goals`, `wishes`, `crafts`, `class`, `recruit`, `journal`) and gains a layer of five main tabs mapping to them; Home is one more content key (`home`) drawn with the existing row system. `Skin.lua` is rewritten for the book look (one style only).

**Tech Stack:** Lua 5.1 (WoW Forever 1.60, interface 16001); tests on node + fengari with `tools/wow-stub.lua` (`npm test`, one test: `node tools/run-lua-test.mjs LevelMates tests/X.test.lua`).

**Spec:** `docs/superpowers/specs/2026-10-11-levelmates-libro-design.md`

## Global Constraints

- Only the game's own art (Forever atlases: `spellbook-Page-Right-C60`, `spellbook-divider`, `spellbook-background-evergreen-ribbon`, `spellbook-Tab-Frame-C60`, game icons); nothing from other addons.
- Nothing posts, invites, whispers or creates anything without a click; the policy check in `npm test` stays green.
- Addon messages to the guild only, ≤255 bytes; only roster mates are believed.
- Every string in both `Locales/enUS.lua` and `Locales/esES.lua`.
- One style: the classic style option is removed.

## Review Focus

1. A week boundary while playing: weekly counters reset for me and old-week numbers from others stop counting in the challenge and rankings — test in Points.
2. A guildmate who left the guild or was not seen for 30 days stops counting in the guild total — test in Points.
3. The challenge done notice fires once, also after /reload — test in Points.
4. Home with nobody online shows the invite text and the guild block, nothing broken — test in Home.
5. Old commands (`/lm metas`, `/lm oficios`, `/lm clase`, `B.ShowTab("feed")`) still land on their content inside the Guild tab — test in Board.

---

### Task 1: Points.lua — counting, sharing and summing

**Files:** Create `LevelMates/Points.lua`; modify `Comm.lua` (kind `pt`), `Core.lua` (DEFAULTS `sharePoints = true`), `Settings.lua` (option), `Help.lua` (fire `LM_HELP_GIVEN` from `H.Coming`, once per request), `Gifts.lua` (fire `LM_GIFT_GIVEN` when I confirm a reservation for the first time), `Trainer.lua` (keep `T.Due()` list until the next trainer visit), toc, locales. Test: `tests/points.test.lua`.

**Interfaces (produces):**
- `PT.Week(t)` → week number (Monday 00:00 server time; `GetServerTime` when present, else `time`).
- `PT.Mine()` → `{ t, w, l, d, h, q }` (counters reset when the week changes).
- `PT.Add(cat, n)` internal; events: `PLAYER_LEVEL_UP` (+10, l), `LM_JOURNAL_ADDED` dungeon with mates (+15, d), `QUEST_TURNED_IN` (+1, q), `LM_HELP_GIVEN` (+5, h), `LM_GIFT_GIVEN` (+5), meetup attended (+10: within its hour, grouped with its creator, I joined or created it; once per meetup).
- kind `pt`: `t` int 0-100000000, `w` int 0-100000, `l d h q` int 0-100000; LATEST_ONLY; sent on change (≤ once a minute), on `LM_ANNOUNCED` / `LM_PING_ANSWERED`; pending on drop; `{}` withdraws (option off).
- `PT.Members()` → list `{ name, t, w, l, d, h, q, mine }` (me if sharing; others seen in 30 days and still guildmates, or samples).
- `PT.GuildTotal()`, `PT.Level(total)` → `level, into, need` with cost of N→N+1 = `100 * N`.
- `PT.Challenge()` → `{ cat, goal, have, done, text }`: list `{ {cat="d", base=25}, {cat="l", base=60}, {cat="h", base=15}, {cat="q", base=200} }`, index `week % 4 + 1`, `goal = ceil(base * clamp(players / 5, 0.4, 3))`, players = members with `w == this week`.
- `PT.Rankings()` → `{ l = {top3}, d = {top3}, h = {top3} }`, entries `{ name, n }`, only `n > 0`, this week.
- Notices: guild level up and challenge done (once per week, saved in `ns.db`), each also a local wall entry (`k = "gol"`).

### Task 2: Home.lua — what to do now

**Files:** Create `LevelMates/Home.lua`. Test: `tests/home.test.lua`.

**Interfaces:** `HM.Rows()` → ordered rows for the board:
- `{ header = "guild" }`, `{ kind = "level", level, into, need }`, `{ kind = "challenge", text, have, goal, done }`
- `{ header = "now", count }` + `{ kind = "help", id, name, text, zone }`, `{ kind = "lfg", adId, name, dungeon, roles }`, `{ kind = "meet", meet }` (today)
- `{ header = "foryou", count }` + `{ kind = "mate", name }` (online, ±3 levels or same zone), `{ kind = "gift", name, id, price }` (offered and on my wishes), `{ kind = "trainer", n, names }` (due spells)
- `{ header = "week" }` + `{ kind = "rank", cat, top }` per non-empty category
- `{ kind = "invite" }` when no guildmate is seen.
- Empty sections are left out (the guild block always shows).
- `HM.InviteText()` → the text to copy (guild name, where to get LevelMates).

### Task 3: Board — five tabs, Guild sub-sections, Home content

**Files:** modify `Board.lua`, `DiscordCopy.lua` (home builder), locales; tests updated: `board_tabs`, `board_crafts`, `board_wishes`, `feed`, `board_journal`, `board_class`, `board_lfg`; new `tests/board_book.test.lua`.

- `B.MAIN = { "home", "mates", "lfg", "guild", "journal" }`; `B.GUILD = { "feed", "goals", "wishes", "crafts", "class", "recruit" }`; `B.main` (main tab) and `B.tab` (content key).
- `B.ShowTab(key)`: a main key or a content key; a guild content key selects main `guild`; `guild` opens its last sub-section (default `feed`). The board opens on `home`.
- Main tabs are icon buttons (Task 4 styles them); sub-section buttons (icon + name) appear in the header area on the Guild tab only; Recruit only for officers.
- `home` content: `FillHome(rows)` with the existing rows: section headers, bars for level and challenge (the profession bar), action text in the last column ("Voy", "Me apunto", "Invitar", "Ver"), left click does the action (help → `H.Coming`, lfg → dungeon menu, meet → meetup menu, mate → mate menu, gift → wish menu, trainer → nothing, invite → copy box).
- Discord copy on Home: guild level, challenge, rankings.

### Task 4: Skin — the book look

**Files:** rewrite `Skin.lua`; modify `Board.lua`, dialogs, `Settings.lua` (remove style radios), locales; tests updated: `skin`, `board_template`, `board_template_fallback`; new assertions in `board_book.test.lua`.

- Board frame: `ButtonFrameTemplate` **with portrait** (`SetPortraitToAsset` LevelMates icon), attic kept: icon tabs (40×40, `spellbook-Tab-Frame-C60` around the icon, tooltip with the name, selected one lit) in the attic, search box on its right.
- Page: texture `spellbook-Page-Right-C60` over the inset; ribbon `spellbook-background-evergreen-ribbon` at the page's top right; heading in `Fancy24Font` dark ink; `spellbook-divider` under it; footer hint (`L.HINT_<key>`) at the bottom of the page.
- Section headers: dark translucent band, coloured text `"Name • n"` left (green now, yellow soon, blue info, grey others); rows: thin separator line, no stripes; row text recoloured to ink (`SK.Ink(r,g,b)` = `r*0.45, g*0.40, b*0.32`) and shadows off after each fill; column headers in ink.
- Dungeon cards keep their look over the page.
- Dialogs (`SK.Window`): game frame with the parchment page on the inset.
- Remove `settings.style` and the classic branches; `SK.On()` stays true (kept for tests and fallback code paths).

### Task 5: Sim and docs

- `/lm sim puntos`: sample members with points this week (local only).
- README (en/es): Home, the five tabs, guild progress; CHANGELOG 0.3.0.

Each task: failing test first, implement, `npm test` green, commit.
