# LevelMates dungeon grid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Dungeons tab becomes a grid of dungeon cards with art (as the Forever dungeon journal's home), and the finder knows all fourteen dungeons.

**Architecture:** `Dungeons.lua` grows to fourteen rows, each with its card art (game loading screens; ForeverDungeonJournal's own art only from its folder while it is loaded) and `D.Sorted()`/`D.Art(id)`. `Board.lua` draws one card per dungeon on the Dungeons tab instead of list rows; a card's tooltip lists the ads and its click menu whispers/invites, withdraws mine, or opens the group dialog with that dungeon (`LM_LFG_HERE`).

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.x); node + fengari tests with `tools/wow-stub.lua`.

**Spec:** `docs/superpowers/specs/2026-10-10-levelmates-dungeon-grid-design.md`

## Global Constraints

- Dungeon ids 1-6 keep their meaning (they travel in `lfg` and `dun` goals).
- No art from another addon is copied into LevelMates; its paths are used only while that addon is loaded.
- Actions (whisper, invite, withdraw, open dialog) only from clicks.
- Strings in both locale files; `tests/policy.test.mjs` checks every `DUNGEON_*` key in both.

## Review Focus

1. ForeverDungeonJournal not installed: Hall of Thanes and Ruins show no art, the Library falls back to the Graveyard screen (Task 1 tests).
2. My own ad: counted on its card and offered as "Withdraw my ad", never "Whisper me" (Task 2 tests).
3. Search by a player's name finds the card of the dungeon they look for (Task 2 tests).
4. Switching tabs hides every card; other tabs keep their rows (Task 2 tests).
5. "Look for a group here" opens the dialog with that dungeon already chosen (Task 2 tests).

---

### Task 1: Fourteen dungeons with card art

**Files:** Modify `LevelMates/Dungeons.lua`, locales, `tools/wow-stub.lua`; create `tests/dungeons.test.lua`.

**Interfaces:** Produces `D.list` (14 rows: `id, key, min, max, art, coords, needs?, fallback?, fallbackCoords?`), `D.Sorted()`, `D.Art(id) -> texture|nil, coords`.

- [ ] **Step 1: Stub.** In `tools/wow-stub.lua` replace `function Region:SetTexture(t) self.atlas = nil end` with `function Region:SetTexture(t) self.atlas = nil; self.texture = t end`, and after `C_AddOns = { GetAddOnMetadata = function() return "dev" end }` add `C_AddOns.IsAddOnLoaded = function(name) return STUB.loadedAddons ~= nil and STUB.loadedAddons[name] == true end`.

- [ ] **Step 2: Failing test** — `tests/dungeons.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
local D, L = ns.Dungeons, ns.L
assert(#D.list == 14, "fourteen dungeons: " .. #D.list)
local seen = {}
for _, d in ipairs(D.list) do
	assert(not seen[d.id] and d.id >= 1 and d.id <= 14, "unique ids")
	seen[d.id] = true
	assert(type(L[d.key]) == "string" and L[d.key] ~= "", "named: " .. d.key)
	assert(d.min < d.max, "a level range")
end
assert(D.Name(5) == "The Deadmines" and D.Name(8) == "The Stockade" and D.Get(14).min == 33 and D.Get(14).max == 41, "known rows")
local sorted = D.Sorted()
for i = 2, #sorted do
	local a, b = sorted[i - 1], sorted[i]
	assert(a.min < b.min or a.min == b.min and (a.max < b.max or a.max == b.max and a.id < b.id), "by level")
end
local tex, coords = D.Art(2)
assert(tex == "Interface\\Glues\\LoadingScreens\\LoadScreenRagefireChasm" and coords[3] == 0.25, "game loading screen, cropped")
assert(D.Art(8) == 131870, "file ids work too")
assert(D.Art(1) == nil and D.Art(3) == nil, "the journal addon's own art: not without it")
assert(D.Art(14) == "Interface\\Glues\\LoadingScreens\\LoadScreenScarletMonastery2", "the Library falls back to the Graveyard")
STUB.loadedAddons = { ForeverDungeonJournal = true }
assert(D.Art(1) == "Interface\\AddOns\\ForeverDungeonJournal\\Media\\HallOfThanes", "its art while it is loaded")
assert(D.Art(14) == "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ScarletMonasteryLibraryHome", "the Library's own art")
```

- [ ] **Step 3: Run** — `node tools/run-lua-test.mjs LevelMates tests/dungeons.test.lua` — Expected: LUA ERROR at `fourteen dungeons`.

- [ ] **Step 4: Implement.** Replace `LevelMates/Dungeons.lua` with:

```lua
-- Dungeons.lua: the dungeons the group finder knows, with their card art: the fourteen of the Forever dungeon journal.
-- To add one, append a row here and add its DUNGEON_* name to both locale files (tests/policy.test.mjs checks that).
-- Ids 1-6 travel in messages (lfg, dun goals): never renumber them.
local _, ns = ...
local D = {}
ns.Dungeons = D

-- Card art: the game's own loading screens, cropped as the dungeon journal does. ForeverDungeonJournal's own
-- pictures are used from its folder only while it is loaded; they are never copied here.
local LS = "Interface\\Glues\\LoadingScreens\\"
local FDJ = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\"
local WIDE, TALL = { 0.02, 0.98, 0.25, 0.82 }, { 0.02, 0.98, 0.24, 0.82 }
local NEW, OWN = { 0, 1, 0.12, 0.88 }, { 0.03, 0.97, 0.05, 0.95 }

D.list = {
	{ id = 1,  key = "DUNGEON_HALL_OF_THANES",      min = 13, max = 20, needs = "ForeverDungeonJournal", art = FDJ .. "HallOfThanes", coords = OWN },
	{ id = 2,  key = "DUNGEON_RAGEFIRE_CHASM",      min = 13, max = 18, art = LS .. "LoadScreenRagefireChasm", coords = WIDE },
	{ id = 3,  key = "DUNGEON_RUINS_OF_LORDAERON",  min = 15, max = 22, needs = "ForeverDungeonJournal", art = FDJ .. "RuinsOfLordaeron", coords = OWN },
	{ id = 4,  key = "DUNGEON_WAILING_CAVERNS",     min = 15, max = 24, art = LS .. "LoadScreenWailingCaverns", coords = WIDE },
	{ id = 5,  key = "DUNGEON_DEADMINES",           min = 17, max = 26, art = LS .. "LoadScreenDeadmines", coords = WIDE },
	{ id = 6,  key = "DUNGEON_SHADOWFANG_KEEP",     min = 20, max = 30, art = LS .. "LoadScreenShadowFangKeep", coords = TALL },
	{ id = 7,  key = "DUNGEON_BLACKFATHOM_DEEPS",   min = 24, max = 32, art = LS .. "LoadScreenBlackFathomDeeps", coords = WIDE },
	{ id = 8,  key = "DUNGEON_STOCKADE",            min = 24, max = 32, art = 131870, coords = TALL },
	{ id = 9,  key = "DUNGEON_EXCAVATION_WETLANDS", min = 26, max = 33, art = 7963777, coords = NEW },
	{ id = 10, key = "DUNGEON_DALARAN",             min = 28, max = 33, art = 7963775, coords = NEW },
	{ id = 11, key = "DUNGEON_GNOMEREGAN",          min = 29, max = 38, art = LS .. "LoadScreenGnomeregan", coords = TALL },
	{ id = 12, key = "DUNGEON_RAZORFEN_KRAUL",      min = 29, max = 38, art = 131865, coords = TALL },
	{ id = 13, key = "DUNGEON_SM_GRAVEYARD",        min = 30, max = 38, art = LS .. "LoadScreenScarletMonastery2", coords = TALL },
	{ id = 14, key = "DUNGEON_SM_LIBRARY",          min = 33, max = 41, needs = "ForeverDungeonJournal", art = FDJ .. "ScarletMonasteryLibraryHome", coords = { 0, 1, 0.06, 0.94 },
		fallback = LS .. "LoadScreenScarletMonastery2", fallbackCoords = TALL },
}

local byId = {}
for _, d in ipairs(D.list) do byId[d.id] = d end

function D.Get(id) return byId[id] end
function D.Name(id) local d = byId[id]; return d and ns.L[d.key] or ("#" .. tostring(id)) end
function D.Fits(id, level) local d = byId[id]; return d ~= nil and type(level) == "number" and level >= d.min and level <= d.max end

-- By level range, for the cards.
function D.Sorted()
	local out = {}
	for _, d in ipairs(D.list) do out[#out + 1] = d end
	table.sort(out, function(a, b)
		if a.min ~= b.min then return a.min < b.min end
		if a.max ~= b.max then return a.max < b.max end
		return a.id < b.id
	end)
	return out
end

-- The card's texture (path or file id) and crop; nil when there is none to show.
function D.Art(id)
	local d = byId[id]
	if not d then return nil end
	if d.needs and not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(d.needs)) then return d.fallback, d.fallbackCoords end
	return d.art, d.coords
end
```

Locales — `enUS.lua`:

```lua
L.DUNGEON_BLACKFATHOM_DEEPS = "Blackfathom Deeps"; L.DUNGEON_STOCKADE = "The Stockade"; L.DUNGEON_EXCAVATION_WETLANDS = "Excavation Site: Wetlands"
L.DUNGEON_DALARAN = "City of Dalaran"; L.DUNGEON_GNOMEREGAN = "Gnomeregan"; L.DUNGEON_RAZORFEN_KRAUL = "Razorfen Kraul"
L.DUNGEON_SM_GRAVEYARD = "Scarlet Monastery: Graveyard"; L.DUNGEON_SM_LIBRARY = "Scarlet Monastery: Library"
```
`esES.lua`:

```lua
L.DUNGEON_BLACKFATHOM_DEEPS = "Cavernas de Brazanegra"; L.DUNGEON_STOCKADE = "Las Mazmorras"; L.DUNGEON_EXCAVATION_WETLANDS = "Excavación: Los Humedales"
L.DUNGEON_DALARAN = "Ciudad de Dalaran"; L.DUNGEON_GNOMEREGAN = "Gnomeregan"; L.DUNGEON_RAZORFEN_KRAUL = "Horado Rajacieno"
L.DUNGEON_SM_GRAVEYARD = "Monasterio Escarlata: Cementerio"; L.DUNGEON_SM_LIBRARY = "Monasterio Escarlata: Biblioteca"
```

- [ ] **Step 5: Run** the test (Expected `ok`) and `npm test` (all `ok`).

- [ ] **Step 6: Commit** — `git add LevelMates/Dungeons.lua LevelMates/Locales/enUS.lua LevelMates/Locales/esES.lua tools/wow-stub.lua tests/dungeons.test.lua` — `feat(lfg): fourteen dungeons with card art`.

---

### Task 2: The dungeon grid on the Dungeons tab

**Files:** Modify `LevelMates/Board.lua`, `LevelMates/LfgDialog.lua`, locales; replace `tests/board_lfg.test.lua`.

**Interfaces:** Consumes `D.Sorted/Art/Get/Name/Fits`. Produces `B.cards` (buttons with `dungeonId`, `fits`, `art`, `name`, `levels`, `count`), `B.AdsFor(id)`, `B.DungeonTooltip(card)`, `B.OpenDungeonMenu(id)`, `B.lastDungeonMenu`, event `LM_LFG_HERE(id)`.

- [ ] **Step 1: Failing test** — replace `tests/board_lfg.test.lua` with:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, G, D, L = ns.Comm, ns.Board, ns.LFG, ns.Dungeons, ns.L
STUB.player.level = 15
local function mate(name, level, class) STUB.Receive("LVLM", C.Encode("hb", { l = level, z = 1421, c = class }), "GUILD", name .. "-Testrealm") end
local function ad(from, f) STUB.Receive("LVLM", C.Encode("lfg", f), "GUILD", from .. "-Testrealm") end
mate("Mario", 18, "MAGE"); mate("Ana", 12)
ad("Mario", { d = 2, r = "TD", n = "con agua", id = "m0000001", m = 15 })
STUB.Advance(31)
ad("Ana", { d = 2, r = "H", id = "a0000001", m = 20 })
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function pick(text) for _, e in ipairs(entries) do if e.text == text then e.cb(); return true end end; return false end
local function cardOf(id) for _, c in ipairs(B.cards) do if c:IsShown() and c.dungeonId == id then return c end end end
local function shownIds() local out = {}; for _, c in ipairs(B.cards) do if c:IsShown() then out[#out + 1] = c.dungeonId end end; return out end
local function search(text) B.searchBox:SetText(text); B.searchBox.scripts.OnTextChanged(B.searchBox) end
B.Toggle()

assert(B.tab == "mates" and B.helpButton:IsShown() and not B.lfgButton:IsShown() and #shownIds() == 0, "starts on guildmates, no cards")
B.tabs.lfg.scripts.OnClick(B.tabs.lfg)
assert(B.tab == "lfg" and ns.char.boardTab == "lfg" and B.tabs.lfg.enabled == false, "tab switched and remembered")
local ids = shownIds()
assert(#ids == 14, "a card per dungeon: " .. #ids)
for i, d in ipairs(D.Sorted()) do assert(ids[i] == d.id, "cards by level") end
for i = 1, #B.rows do assert(not B.rows[i].button:IsShown(), "no list rows on this tab") end
assert(B.headText[1].text == "" and B.headText[3].text == "", "no column headers")
local rfc = cardOf(2)
assert(rfc.name.text == D.Name(2) and rfc.levels.text == "13-18" and rfc.count.text == string.format(L.LFG_SEARCHING, 2), "name, levels, 2 looking")
assert(cardOf(6).count.text == "", "nobody for Shadowfang")
assert(rfc.fits and not cardOf(6).fits, "my level fits Ragefire, not Shadowfang")
assert(rfc.art:IsShown() and rfc.art.texture == "Interface\\Glues\\LoadingScreens\\LoadScreenRagefireChasm" and rfc.art.texcoord[3] == 0.25, "the loading screen, cropped")
assert(not cardOf(1).art:IsShown(), "Hall of Thanes: no art without the journal addon")
STUB.loadedAddons = { ForeverDungeonJournal = true }; B.Refresh()
assert(cardOf(1).art:IsShown() and cardOf(1).art.texture == "Interface\\AddOns\\ForeverDungeonJournal\\Media\\HallOfThanes", "its art while the journal addon is loaded")

-- hover: every ad
rfc = cardOf(2)
rfc.scripts.OnEnter(rfc)
local lines = table.concat(GameTooltip.lines, "\n")
assert(lines:find("Mario", 1, true) and lines:find("con agua", 1, true) and lines:find("Ana", 1, true) and not GameTooltip.hidden, "tooltip lists the ads: " .. lines)
rfc.scripts.OnLeave(rfc)
assert(GameTooltip.hidden, "tooltip hides")

-- click: whisper or invite each, or look for a group here
rfc.scripts.OnClick(rfc, "LeftButton")
assert(B.lastDungeonMenu == 2, "menu for the card")
assert(pick(string.format(L.LFG_WHISPER, "Mario")) and STUB.lastTell == "Mario", "whisper Mario")
local invites = 0
for _, e in ipairs(entries) do if e.text == string.format(L.LFG_INVITE, "Ana") then invites = invites + 1 end end
assert(invites == 1, "invite Ana")
rfc.scripts.OnClick(rfc, "LeftButton")
assert(pick(L.LFG_HERE) and ns.LfgDialog.frame:IsShown() and ns.LfgDialog.dungeon == 2, "the dialog opens with Ragefire chosen")
ns.LfgDialog.frame:Hide()

-- search: by dungeon or by who is looking
search("mario"); assert(#shownIds() == 1 and shownIds()[1] == 2, "by player")
search("shadow"); assert(#shownIds() == 1 and shownIds()[1] == 6, "by dungeon")
search("zzz"); assert(#shownIds() == 0 and B.frame.empty.text == L.EMPTY_FILTERED, "nothing matches")
search("")

-- my own ad: counted, offered as withdraw
STUB.Advance(31)
assert(G.Post(5, "T"), "I post for the Deadmines")
local dm = cardOf(5)
assert(dm.count.text == L.LFG_SEARCHING_ONE, "my ad counts")
dm.scripts.OnClick(dm, "LeftButton")
local whisperMe = false
for _, e in ipairs(entries) do if e.text == string.format(L.LFG_WHISPER, "Tester") then whisperMe = true end end
assert(not whisperMe and pick(L.LFG_CANCEL_MINE) and G.mine == nil, "withdraw, never whisper myself")

-- the bottom button and the other tabs
assert(B.lfgButton:IsShown() and not B.helpButton:IsShown() and not B.nearCheck:IsShown(), "lfg tab buttons")
local clicks = 0
ns.On("LM_LFG_BUTTON", function() clicks = clicks + 1 end)
B.lfgButton.scripts.OnClick(B.lfgButton)
assert(clicks == 1, "the button fires LM_LFG_BUTTON")
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(#shownIds() == 0 and B.helpButton:IsShown() and B.headText[1].text == L.COL_NAME, "guildmates: cards hidden, headers back")
B.Toggle()
B.ShowTab("lfg")
assert(B.frame:IsShown() and B.tab == "lfg" and #shownIds() == 14, "ShowTab opens the grid")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR at `starts on guildmates, no cards` (no `B.cards`).

- [ ] **Step 3: Implement**

Locales — `enUS.lua`: `L.LFG_SEARCHING = "%d looking"; L.LFG_SEARCHING_ONE = "1 looking"; L.LFG_WHISPER = "Whisper %s"; L.LFG_INVITE = "Invite %s"; L.LFG_HERE = "Look for a group here"; L.LFG_CANCEL_MINE = "Withdraw my ad"`. `esES.lua`: `L.LFG_SEARCHING = "%d buscan"; L.LFG_SEARCHING_ONE = "1 busca"; L.LFG_WHISPER = "Susurrar a %s"; L.LFG_INVITE = "Invitar a %s"; L.LFG_HERE = "Buscar grupo aquí"; L.LFG_CANCEL_MINE = "Retirar mi anuncio"`.

`LfgDialog.lua`, at the end:

```lua

-- A dungeon card's "Look for a group here": the dialog with that dungeon chosen.
ns.On("LM_LFG_HERE", function(id) Dlg.Open(); Dlg.SelectDungeon(id) end)
```

`Board.lua`:

(a) After `B.WCOLS = …` add `B.CARD_COLS, B.CARD_GAP, B.CARD_H, B.ART_H = 4, 6, 96, 58   -- dungeon cards`.

(b) After the line `	f.empty = Col(f, B.WIDTH - 40, "CENTER"); f.empty:SetPoint("TOP", 0, -(B.TOP + 40))` add:

```lua

	-- Dungeons tab: a card per dungeon (art, name, levels, how many are looking), as the dungeon journal's home.
	B.CARD_W = math.floor((B.WIDTH - 2 * B.MARGIN - (B.CARD_COLS - 1) * B.CARD_GAP) / B.CARD_COLS)
	B.cards = {}
	for i = 1, #ns.Dungeons.list do
		local c = CreateFrame("Button", nil, f)
		c:SetSize(B.CARD_W, B.CARD_H); c:RegisterForClicks("AnyUp")
		c:SetHighlightTexture("Interface/QuestFrame/UI-QuestLogTitleHighlight", "ADD")
		c.bg = c:CreateTexture(nil, "BACKGROUND"); c.bg:SetAllPoints()
		c.art = c:CreateTexture(nil, "ARTWORK"); c.art:SetPoint("TOPLEFT", 3, -3); c.art:SetPoint("TOPRIGHT", -3, -3); c.art:SetHeight(B.ART_H)
		c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		c.name:SetPoint("TOPLEFT", 5, -(B.ART_H + 6)); c.name:SetWidth(B.CARD_W - 10); c.name:SetJustifyH("LEFT"); c.name:SetWordWrap(false)
		c.levels = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.levels:SetPoint("BOTTOMLEFT", 5, 5)
		c.count = c:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall"); c.count:SetPoint("BOTTOMRIGHT", -5, 5)
		c:SetScript("OnClick", function(self) B.OpenDungeonMenu(self.dungeonId) end)
		c:SetScript("OnEnter", function(self) B.DungeonTooltip(self) end)
		c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		c:Hide()
		B.cards[i] = c
	end
```

(c) Delete the whole `local function LfgVisible() … end` (with its comment line) and the whole `local function FillLfg(list) … end`.

(d) `SetHeaders`: right after `	local lfg = B.tab == "lfg"` insert:

```lua
	if lfg then for i = 1, 5 do B.headText[i]:SetText("") end; return end   -- the grid has no columns
```

(e) Before `function B.OpenMyGoalMenu()` add:

```lua
-- Dungeons tab: the ads for a dungeon (mine first), the visible cards, and filling them.
function B.AdsFor(id)
	local out, LFG = {}, ns.LFG
	if LFG.mine and LFG.mine.d == id then out[1] = { name = (UnitName("player")), r = LFG.mine.r, n = LFG.mine.n, mine = true } end
	for _, adId in ipairs(LFG.List()) do
		local a = LFG.ads[adId]
		if a.d == id and not (LFG.mine and adId == LFG.mine.id) then out[#out + 1] = a end
	end
	return out
end

local function GridVisible()
	local out, q = {}, (B.search or ""):lower()
	for _, d in ipairs(ns.Dungeons.Sorted()) do
		local match = q == "" or ns.Dungeons.Name(d.id):lower():find(q, 1, true) ~= nil
		if not match then for _, a in ipairs(B.AdsFor(d.id)) do if a.name:lower():find(q, 1, true) then match = true end end end
		if match then out[#out + 1] = d.id end
	end
	return out
end

local function FillGrid(list)
	for i = 1, ROWS do ClearRow(B.rows[i]) end
	local mine = UnitLevel("player")
	for i, c in ipairs(B.cards) do
		local id = list[i]
		if id then
			local d, ads = ns.Dungeons.Get(id), B.AdsFor(id)
			local col, row = (i - 1) % B.CARD_COLS, math.floor((i - 1) / B.CARD_COLS)
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", B.frame, "TOPLEFT", B.MARGIN + col * (B.CARD_W + B.CARD_GAP), -(B.TOP + row * (B.CARD_H + B.CARD_GAP)))
			c.dungeonId, c.fits = id, ns.Dungeons.Fits(id, mine)
			local tex, coords = ns.Dungeons.Art(id)
			if tex then c.art:SetTexture(tex); c.art:SetTexCoord(unpack(coords)); c.art:SetAlpha(c.fits and 1 or 0.45); c.art:Show() else c.art:Hide() end
			c.bg:SetColorTexture(unpack(c.fits and { 0.35, 0.27, 0.05, 0.9 } or { 0.08, 0.08, 0.08, 0.9 }))
			c.name:SetText(ns.Dungeons.Name(id)); c.name:SetTextColor(unpack(c.fits and { 1, 0.82, 0 } or { 0.75, 0.75, 0.75 }))
			c.levels:SetText(string.format("%d-%d", d.min, d.max))
			c.count:SetText(#ads == 0 and "" or #ads == 1 and L.LFG_SEARCHING_ONE or string.format(L.LFG_SEARCHING, #ads))
			c:Show()
		else
			c:Hide()
		end
	end
end

function B.DungeonTooltip(card)
	if not GameTooltip then return end
	local d = ns.Dungeons.Get(card.dungeonId)
	GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
	GameTooltip:AddLine(string.format("%s (%d-%d)", ns.Dungeons.Name(d.id), d.min, d.max), 1, 0.82, 0)
	for _, a in ipairs(B.AdsFor(d.id)) do
		GameTooltip:AddLine(a.name .. " · " .. ns.LFG.RolesShort(a.r) .. (a.n and (": " .. a.n) or ""), 1, 1, 1, true)
	end
	GameTooltip:Show()
end

-- A card's click: whisper or invite who is looking, withdraw mine, or look for a group there.
function B.OpenDungeonMenu(id)
	B.lastDungeonMenu = id
	MenuUtil.CreateContextMenu(B.frame, function(_, root)
		root:CreateTitle(ns.Dungeons.Name(id))
		for _, a in ipairs(B.AdsFor(id)) do
			if a.mine then
				root:CreateButton(L.LFG_CANCEL_MINE, function() ns.LFG.Cancel() end)
			else
				root:CreateButton(string.format(L.LFG_WHISPER, a.name), function() B.Whisper(a.name) end)
				root:CreateButton(string.format(L.LFG_INVITE, a.name), function() B.Invite(a.name) end)
			end
		end
		root:CreateButton(L.LFG_HERE, function() ns.Fire("LM_LFG_HERE", id) end)
	end)
end

```

(f) `B.Refresh`:
- replace `		list = lfg and LfgVisible() or Visible()` with `		list = lfg and GridVisible() or Visible()`;
- replace `	B.frame:SetHeight(B.CHROME + (math.max(MIN_ROWS, math.min(ROWS, #list)) + HELP_ROWS) * ROW_H)` with:

```lua
	local rows = math.max(MIN_ROWS, math.min(ROWS, #list))
	if lfg then rows = math.max(MIN_ROWS, math.ceil(math.ceil(#list / B.CARD_COLS) * (B.CARD_H + B.CARD_GAP) / ROW_H)) end
	B.frame:SetHeight(B.CHROME + (rows + HELP_ROWS) * ROW_H)
```
- replace `elseif lfg then FillLfg(list) else FillMates(list) end` with `elseif lfg then FillGrid(list) else FillMates(list) end`, and right after that line add `	if not lfg then for _, c in ipairs(B.cards) do c:Hide() end end`;
- replace `		elseif lfg then emptyText = #ns.LFG.List() > 0 and L.EMPTY_FILTERED or L.LFG_EMPTY` with `		elseif lfg then emptyText = L.EMPTY_FILTERED   -- every dungeon has a card: empty only when the search hides them all`.

- [ ] **Step 4: Run** the test (Expected `ok`) and `npm test` (all `ok`; `discord_copy` and `sim` use `ns.LFG`, not the rows).

- [ ] **Step 5: Commit** — `git add LevelMates/Board.lua LevelMates/LfgDialog.lua LevelMates/Locales/enUS.lua LevelMates/Locales/esES.lua tests/board_lfg.test.lua` — `feat(board): dungeon grid with art on the Dungeons tab`.
