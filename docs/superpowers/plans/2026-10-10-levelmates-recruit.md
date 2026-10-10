# LevelMates recruitment tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Officers and the guild master post a guild recruitment message to channel 2 (Trade) or 1 (General) from a tab, with three shared templates, a 10-minute wait shared by all officers and an optional reminder every 10 minutes.

**Architecture:** `Recruit.lua` keeps the templates and the last post per guild (`rt` template, `rc` posted, officers only), expands placeholders, and shows the reminder prompt; the eighth board tab (`recruit`, officers only) holds the editors, channel choice, preview, status and the Publish button. Posting is `SendChatMessage(text, "CHANNEL", nil, n)` inside a click handler only (policy).

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.x); node + fengari tests with `tools/wow-stub.lua`.

**Spec:** the design approved in chat on 2026-10-10 (user: "ok"): officers' tab; 3 shared templates with `{hermandad}/{guild}`, `{conectados}/{online}`, `{nivel}/{level}`; channels 2 and 1; 10-minute wait shared between officers ("Último anuncio: hace 3 min (Jefa)"); a "Reminder every 10 min" switch that offers a one-click Publish prompt (automatic posting without a click is impossible in the client and against Blizzard's rules).

## Global Constraints

- `SendChatMessage` only inside `OnClick` handlers (policy test). Nothing is ever posted without a click.
- Templates at most 200 bytes, no `|` or control characters; the filled-in message at most 255 bytes.
- `rt`/`rc` are believed only from officers (`R.IsOfficer`).

## Review Focus

1. A non-officer never sees the tab, cannot post, and their `rt`/`rc` are ignored (Task 1 tests).
2. The wait is shared: a post by any officer blocks everyone's Publish for 10 minutes (Task 1 tests).
3. Not being in the chosen channel refuses with a reason instead of failing silently (Task 1 tests).
4. The reminder never posts by itself; "Not now" snoozes it 10 minutes (Task 2 tests).
5. Placeholders filled in correctly, and a guild name containing `%` does not break them (Task 1 tests).

---

### Task 1: Templates, posting and the Recruit tab

**Files:** Create `LevelMates/Recruit.lua`, `tests/recruit.test.lua`. Modify `Comm.lua`, `Board.lua`, `LevelMates.toc` (`Recruit.lua` after `GuildMap.lua`), `tools/wow-stub.lua`, locales.

**Interfaces:** Produces `ns.Recruit` with `GAP`, `Templates()`, `Last()`, `Wait()`, `Expand(text)`, `Prepare(index, channel)`, `Posted()`, `SetTemplate(i, text)`; board `B.recruitPanel`, `B.recruitEdit[1..3]`, `B.recruitUse[1..3]`, `B.recruitChannel[2|1]`, `B.recruitPreview`, `B.recruitStatus`, `B.recruitPost`, `B.recruitRemind`; event `LM_RECRUIT_CHANGED`; slash `/lm reclutar`.

- [ ] **Step 1: Stub** — append to `tools/wow-stub.lua`:

```lua

-- Guild member counts (total, total, online)
function GetNumGuildMembers() return STUB.guildTotal or 0, STUB.guildTotal or 0, STUB.guildOnline or 0 end
```

- [ ] **Step 2: Failing test** — `tests/recruit.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, RC, R, L = ns.Comm, ns.Board, ns.Recruit, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function said(text) for i = #STUB.printed, 1, -1 do if STUB.printed[i]:find(text, 1, true) then return true end end; return false end
STUB.guildMembers = { Tester = true, Jefa = true, Mario = true }
STUB.guildRoles = { Jefa = 2 }
R.InvalidateGuildRoster()
STUB.Receive("LVLM", C.Encode("hb", { l = 40, z = 1421 }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.player.level = 30; STUB.guildOnline = 7; STUB.channels[2] = 2

assert(C.Validate("rt", { i = 2, x = "hola" }) and C.Validate("rt", { i = 4, x = "x" }) == false and C.Validate("rc", { t = 100 }), "formats")
assert(RC.Expand("{hermandad} · {conectados} · {nivel}") == "Test Guild · 7 · 30", "placeholders: " .. RC.Expand("{hermandad} · {conectados} · {nivel}"))
STUB.player.guild = "100% Pros"
assert(RC.Expand("{guild}!") == "100% Pros!", "a % in the guild name")
STUB.player.guild = "Test Guild"

-- officers only
B.Toggle()
assert(not B.tabs.recruit:IsShown(), "members do not see the tab")
assert(not RC.SetTemplate(2, "x") and RC.Prepare(1, 2) == nil, "members cannot edit or post")
STUB.iAmOfficer = true
B.ShowTab("recruit")
assert(B.tabs.recruit:IsShown() and B.recruitPanel:IsShown() and B.heading.text == L.HEAD_RECRUIT, "officers do")
assert(B.recruitEdit[1]:GetText() == L.RECRUIT_DEFAULT, "a default template")
for i = 1, #B.rows do assert(not B.rows[i].button:IsShown(), "no list rows here") end

-- edit, share, pick, preview, post
B.recruitEdit[2]:SetText("Somos {hermandad}"); B.recruitEdit[2].scripts.OnEnterPressed(B.recruitEdit[2])
assert(RC.Templates()[2] == "Somos {hermandad}" and last("rt").i == 2 and last("rt").x == "Somos {hermandad}", "saved and shared")
B.recruitUse[2]:SetChecked(true); B.recruitUse[2].scripts.OnClick(B.recruitUse[2])
assert(B.recruitPreview.text == "Somos Test Guild", "preview")
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(STUB.lastChat and STUB.lastChat.msg == "Somos Test Guild" and STUB.lastChat.chatType == "CHANNEL" and STUB.lastChat.target == 2, "posted to channel 2")
assert(last("rc") and RC.Last().by == "Tester", "the wait starts for everyone")

-- the wait is shared
STUB.lastChat = nil
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(STUB.lastChat == nil and said(string.format(L.RECRUIT_WAIT, 10)), "wait 10 minutes")
STUB.Advance(RC.GAP + 1)
STUB.Receive("LVLM", C.Encode("rc", { t = math.floor(time() / 60) }), "GUILD", "Jefa-Testrealm")
assert(RC.Last().by == "Jefa" and RC.Wait() > 0, "Jefa just posted")
assert(B.recruitStatus.text:find("Jefa", 1, true), "status shows who")
STUB.Receive("LVLM", C.Encode("rc", { t = math.floor(time() / 60) + 5 }), "GUILD", "Mario-Testrealm")
assert(RC.Last().by == "Jefa", "members' rc ignored")

-- shared templates: officers only
STUB.Receive("LVLM", C.Encode("rt", { i = 3, x = "Plantilla de Jefa" }), "GUILD", "Jefa-Testrealm")
STUB.Receive("LVLM", C.Encode("rt", { i = 3, x = "Spam de Mario" }), "GUILD", "Mario-Testrealm")
assert(RC.Templates()[3] == "Plantilla de Jefa" and B.recruitEdit[3]:GetText() == "Plantilla de Jefa", "Jefa's template")

-- not in the channel: refused with the reason
STUB.Advance(RC.GAP + 1)
B.recruitChannel[1]:SetChecked(true); B.recruitChannel[1].scripts.OnClick(B.recruitChannel[1])
B.recruitPost.scripts.OnClick(B.recruitPost)
assert(STUB.lastChat == nil and said(string.format(L.RECRUIT_NO_CHANNEL, 1)), "not in channel 1")

-- members again: no tab
STUB.iAmOfficer = false
B.Refresh()
assert(not B.tabs.recruit:IsShown() and B.tab ~= "recruit", "back to a member's tabs")
```

- [ ] **Step 3: Run** — Expected: LUA ERROR at `formats`.

- [ ] **Step 4: Implement**

`Comm.lua`: schemas `rt   = { i = int(1, 3), x = text(200) },` and `rc   = { t = int(0, 100000000) },`; REQUIRED `rt = { "i" }, rc = { "t" }`.

`LevelMates/Recruit.lua`:

```lua
-- Recruit.lua: guild recruitment for officers and the guild master. Three templates shared between officers (`rt`),
-- placeholders filled in at post time, posted to channel 2 (Trade) or 1 (General) only from a click, with a
-- 10-minute wait shared by all officers (`rc`). Automatic posting is impossible in the client and against the rules:
-- the reminder only offers a one-click Publish.
local _, ns = ...
local RC = {}
ns.Recruit = RC
local L, C, R = ns.L, ns.Comm, ns.Roster
RC.GAP, RC.MAX_LEN = 600, 200

local function me() return (UnitName("player")) end
local function store()
	ns.db.recruit = ns.db.recruit or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.recruit[k] = ns.db.recruit[k] or { templates = { L.RECRUIT_DEFAULT, "", "" } }
	return ns.db.recruit[k]
end
function RC.Templates() return store().templates end
function RC.Last() return store().last end   -- { at = seconds, by = name }
function RC.Wait()
	local l = store().last
	if not l then return 0 end
	return math.max(0, RC.GAP - (time() - l.at))
end

local function plain(v) return (tostring(v):gsub("%%", "%%%%")) end
-- {hermandad}/{guild}, {conectados}/{online}, {nivel}/{level}; at most 255 bytes once filled in.
function RC.Expand(text)
	local guild = plain(GetGuildInfo("player") or "")
	local online = plain(select(3, GetNumGuildMembers()) or 0)
	local sum, n = UnitLevel("player"), 1
	for _, m in pairs(R.mates) do if m.level then sum, n = sum + m.level, n + 1 end end
	local level = plain(math.floor(sum / n + 0.5))
	local out = tostring(text or "")
	out = out:gsub("{hermandad}", guild):gsub("{guild}", guild)
	out = out:gsub("{conectados}", online):gsub("{online}", online)
	out = out:gsub("{nivel}", level):gsub("{level}", level)
	return ns.CutUtf8(out, 255)
end

-- Called from the Publish click: the text and channel to post, or nil after saying why.
function RC.Prepare(index, channel)
	if not R.IAmOfficer() then ns.Say(L.GOAL_NOT_OFFICER); return nil end
	local wait = RC.Wait()
	if wait > 0 then ns.Say(L.RECRUIT_WAIT, math.ceil(wait / 60)); return nil end
	local text = RC.Expand(RC.Templates()[index] or "")
	if strtrim(text) == "" then ns.Say(L.RECRUIT_EMPTY); return nil end
	if (GetChannelName(channel)) == 0 then ns.Say(L.RECRUIT_NO_CHANNEL, channel); return nil end
	return text, channel
end

-- After the post: the wait starts for every officer.
function RC.Posted()
	store().last = { at = time(), by = me() }
	C.Send("rc", { t = math.floor(time() / 60) }, "now")
	ns.Fire("LM_RECRUIT_CHANGED")
end

function RC.SetTemplate(i, text)
	if not R.IAmOfficer() or type(i) ~= "number" or i < 1 or i > 3 then return false end
	local clean = (strtrim(tostring(text or "")):gsub("[%c|]", ""))
	clean = ns.CutUtf8(clean, RC.MAX_LEN)
	local t = store().templates
	if t[i] == clean then return true end
	t[i] = clean
	C.Send("rt", { i = i, x = clean ~= "" and clean or nil }, "now")
	ns.Fire("LM_RECRUIT_CHANGED")
	return true
end

C.OnMessage("rt", function(f, name)
	if not R.IsOfficer(name) then return end
	store().templates[f.i] = f.x or ""
	ns.Fire("LM_RECRUIT_CHANGED")
end)

C.OnMessage("rc", function(f, name)
	if not R.IsOfficer(name) then return end
	local at = f.t * 60
	if at > time() + 60 then return end
	local l = store().last
	if not l or at > l.at then store().last = { at = at, by = name }; ns.Fire("LM_RECRUIT_CHANGED") end
end)

-- Officers share the templates and a recent post with newcomers.
ns.On("LM_PING_ANSWERED", function()
	if not R.IAmOfficer() then return end
	for i, x in ipairs(store().templates) do if x ~= "" then C.Send("rt", { i = i, x = x }) end end
	local l = store().last
	if l and time() - l.at < RC.GAP then C.Send("rc", { t = math.floor(l.at / 60) }) end
end)
```

`Board.lua`:
- `B.TAB_KEYS` gains `"recruit"`; `TAB_LABELS` gains `recruit = "TAB_RECRUIT"`; `HEAD_KEY` gains `recruit = "RECRUIT"`;
- after `	B.giftAdd = giftAdd` add:

```lua

	-- Recruit tab (officers): three templates, which one, the channel, a preview, the status and Publish.
	local rp = CreateFrame("Frame", nil, f)
	rp:SetPoint("TOPLEFT", B.MARGIN, -B.TOP); rp:SetSize(B.WIDTH - 2 * B.MARGIN, 300); rp:Hide()
	B.recruitPanel, B.recruitEdit, B.recruitUse, B.recruitChannel = rp, {}, {}, {}
	for i = 1, 3 do
		local use = CreateFrame("CheckButton", nil, rp, "UICheckButtonTemplate")
		use:SetSize(22, 22); use:SetPoint("TOPLEFT", 0, -(i - 1) * 34)
		use:SetScript("OnClick", function() ns.char.recruitTemplate = i; B.Refresh() end)
		local edit = CreateFrame("EditBox", nil, rp, "InputBoxTemplate")
		edit:SetSize(B.WIDTH - 2 * B.MARGIN - 40, 22); edit:SetPoint("LEFT", use, "RIGHT", 10, 0); edit:SetAutoFocus(false); edit:SetMaxLetters(200)
		local function save(self) ns.Recruit.SetTemplate(i, self:GetText()); self:ClearFocus() end
		edit:SetScript("OnEnterPressed", save); edit:SetScript("OnEditFocusLost", save)
		B.recruitUse[i], B.recruitEdit[i] = use, edit
	end
	for k, ch in ipairs({ 2, 1 }) do
		local cb = CreateFrame("CheckButton", nil, rp, "UICheckButtonTemplate")
		cb:SetSize(22, 22); cb:SetPoint("TOPLEFT", (k - 1) * 220, -110)
		cb:SetScript("OnClick", function() ns.char.recruitChannel = ch; B.Refresh() end)
		local label = rp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", cb, "RIGHT", 2, 0); label:SetText(L["RECRUIT_CHANNEL_" .. ch])
		B.recruitChannel[ch] = cb
	end
	local preview = rp:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	preview:SetPoint("TOPLEFT", 4, -146); preview:SetWidth(B.WIDTH - 2 * B.MARGIN - 8); preview:SetJustifyH("LEFT"); preview:SetTextColor(1, 0.75, 0.75)
	B.recruitPreview = preview
	local status = rp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	status:SetPoint("TOPLEFT", 4, -200); status:SetJustifyH("LEFT"); status:SetTextColor(0.7, 0.7, 0.7)
	B.recruitStatus = status
	local post = CreateFrame("Button", nil, rp, "UIPanelButtonTemplate")
	post:SetSize(140, 24); post:SetPoint("TOPLEFT", 0, -226); post:SetText(L.RECRUIT_POST)
	post:SetScript("OnClick", function()   -- the only place recruitment reaches a public channel: a click
		local text, ch = ns.Recruit.Prepare(ns.char.recruitTemplate or 1, ns.char.recruitChannel or 2)
		if text then SendChatMessage(text, "CHANNEL", nil, ch); ns.Recruit.Posted() end
	end)
	B.recruitPost = post
	local remind = CreateFrame("CheckButton", nil, rp, "UICheckButtonTemplate")
	remind:SetSize(22, 22); remind:SetPoint("LEFT", post, "RIGHT", 20, 0)
	remind:SetScript("OnClick", function(self) ns.char.recruitRemind = self:GetChecked() and true or false end)
	local remindLabel = rp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	remindLabel:SetPoint("LEFT", remind, "RIGHT", 2, 0); remindLabel:SetText(L.RECRUIT_REMIND)
	B.recruitRemind = remind
```
- before `local function RefreshTabs()` add:

```lua
local function RefreshRecruit()
	local RC, t = ns.Recruit, ns.Recruit.Templates()
	local use, ch = ns.char.recruitTemplate or 1, ns.char.recruitChannel or 2
	for i = 1, 3 do
		if not B.recruitEdit[i]:HasFocus() then B.recruitEdit[i]:SetText(t[i] or "") end
		B.recruitUse[i]:SetChecked(i == use)
	end
	for c, cb in pairs(B.recruitChannel) do cb:SetChecked(c == ch) end
	B.recruitRemind:SetChecked(ns.char.recruitRemind == true)
	B.recruitPreview:SetText(RC.Expand(t[use] or ""))
	local l, wait = RC.Last(), RC.Wait()
	local status = l and string.format(L.RECRUIT_LAST, ns.Journal.Duration(math.max(0, time() - l.at)), l.by) or L.RECRUIT_NONE
	status = status .. "  ·  " .. (wait > 0 and string.format(L.RECRUIT_WAIT, math.ceil(wait / 60)) or L.RECRUIT_READY)
	B.recruitStatus:SetText(status)
end

```
- `RefreshTabs`: add at its start `	if B.tab == "recruit" and not R.IAmOfficer() then B.tab = "mates"; ns.char.boardTab = "mates" end`, and at its end `	B.tabs.recruit:SetShown(R.IAmOfficer())`;
- `B.Refresh`: at its start (after the frame check) add the same officer guard line; extend the tab flags with `, recruit` / `, B.tab == "recruit"`; list branch before `	elseif feed then`: `	elseif recruit then\n		list = {}`; after the fill line add `	B.recruitPanel:SetShown(recruit)\n	if recruit then RefreshRecruit() end`; help rows condition `… or feed or recruit`;
- `SetHeaders`: before `	if B.tab == "feed" then` insert `	if B.tab == "recruit" then for i = 1, 5 do B.headText[i]:SetText("") end; return end`;
- at the end: `ns.On("LM_RECRUIT_CHANGED", B.Refresh)`, `ns.Slash("reclutar", function() B.ShowTab("recruit") end)`, `ns.Slash("recruit", function() B.ShowTab("recruit") end)`.

The stub needs `Region:HasFocus` (returns `self.focused == true`) — append to `tools/wow-stub.lua` with Step 1.

Locales — enUS:

```lua
L.TAB_RECRUIT = "Recruit"; L.HEAD_RECRUIT = "Recruitment"; L.SUB_RECRUIT = "Officers only. Placeholders: {guild}, {online}, {level}."; L.SEARCH_RECRUIT = "Search..."
L.RECRUIT_DEFAULT = "<{guild}> is recruiting! A friendly guild to level up together: dungeon groups, goals and good company. Whisper me!"
L.RECRUIT_CHANNEL_2 = "Channel 2 (Trade)"; L.RECRUIT_CHANNEL_1 = "Channel 1 (General)"; L.RECRUIT_POST = "Post"; L.RECRUIT_REMIND = "Reminder every 10 min"
L.RECRUIT_LAST = "Last post: %s ago (%s)"; L.RECRUIT_NONE = "Nobody has posted yet."; L.RECRUIT_WAIT = "Wait %d min before posting again (shared by all officers)."
L.RECRUIT_READY = "You can post now."; L.RECRUIT_EMPTY = "That template is empty."; L.RECRUIT_NO_CHANNEL = "You are not in channel %d (Trade is only in cities)."
L.RECRUIT_PROMPT = "Time to post the guild recruitment."; L.RECRUIT_LATER = "Not now"
```
esES:

```lua
L.TAB_RECRUIT = "Reclutar"; L.HEAD_RECRUIT = "Reclutamiento"; L.SUB_RECRUIT = "Solo oficiales. Comodines: {hermandad}, {conectados}, {nivel}."; L.SEARCH_RECRUIT = "Buscar..."
L.RECRUIT_DEFAULT = "¡<{hermandad}> recluta! Hermandad tranquila para subir de nivel juntos: grupos de mazmorra, metas y buen rollo. ¡Susúrrame!"
L.RECRUIT_CHANNEL_2 = "Canal 2 (Comercio)"; L.RECRUIT_CHANNEL_1 = "Canal 1 (General)"; L.RECRUIT_POST = "Publicar"; L.RECRUIT_REMIND = "Recordatorio cada 10 min"
L.RECRUIT_LAST = "Último anuncio: hace %s (%s)"; L.RECRUIT_NONE = "Nadie ha publicado todavía."; L.RECRUIT_WAIT = "Espera %d min para volver a publicar (compartido entre oficiales)."
L.RECRUIT_READY = "Ya puedes publicar."; L.RECRUIT_EMPTY = "Esa plantilla está vacía."; L.RECRUIT_NO_CHANNEL = "No estás en el canal %d (el de Comercio solo está en las ciudades)."
L.RECRUIT_PROMPT = "Toca publicar el reclutamiento de la hermandad."; L.RECRUIT_LATER = "Ahora no"
```

- [ ] **Step 5: Run** test and `npm test` (`board_tabs` loops over 8 keys; non-officers have the eighth tab hidden). **Step 6: Commit** — `feat(recruit): officers' recruitment tab with shared templates and a shared wait`.

---

### Task 2: The reminder, simulation and documentation

**Files:** Modify `Recruit.lua`, `README.md`, `CHANGELOG.md`; create `tests/recruit_remind.test.lua`.

**Interfaces:** Produces `ns.Recruit.Tick()`, `Snooze()`, `ShowPrompt()`, `prompt`, `promptPost`, `promptLater`.

- [ ] **Step 1: Failing test** — `tests/recruit_remind.test.lua`:

```lua
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local RC, L = ns.Recruit, ns.L
STUB.iAmOfficer = true; STUB.channels[2] = 2
RC.Tick()
assert(not (RC.prompt and RC.prompt:IsShown()), "off by default")
ns.char.recruitRemind = true
RC.Tick()
assert(RC.prompt and RC.prompt:IsShown() and STUB.lastChat == nil, "offered, never posted by itself")
assert(UIErrorsFrame.messages[#UIErrorsFrame.messages] == L.RECRUIT_PROMPT, "and said on screen")
RC.promptLater.scripts.OnClick(RC.promptLater)
assert(not RC.prompt:IsShown(), "not now")
RC.Tick()
assert(not RC.prompt:IsShown(), "snoozed")
STUB.Advance(RC.GAP + 1); RC.Tick()
assert(RC.prompt:IsShown(), "offered again 10 minutes later")
RC.promptPost.scripts.OnClick(RC.promptPost)
assert(STUB.lastChat and STUB.lastChat.target == 2 and not RC.prompt:IsShown() and RC.Wait() > 0, "one click posts")
RC.Tick()
assert(not RC.prompt:IsShown(), "not during the wait")
STUB.iAmOfficer = false; STUB.Advance(RC.GAP + 1); RC.Tick()
assert(not RC.prompt:IsShown(), "members are never asked")
```

- [ ] **Step 2: Run** — Expected: LUA ERROR (`RC.Tick` is nil).

- [ ] **Step 3: Implement** — append to `Recruit.lua`:

```lua

-- The reminder: every 10 minutes (when the shared wait is over) a small prompt offers Publish; it never posts by itself.
local snoozeUntil = 0
function RC.Snooze() snoozeUntil = time() + RC.GAP; if RC.prompt then RC.prompt:Hide() end end

function RC.ShowPrompt()
	if not RC.prompt then
		local p = CreateFrame("Frame", "LevelMatesRecruitPrompt", UIParent, "BasicFrameTemplateWithInset")
		p:SetSize(320, 96); p:SetPoint("TOP", 0, -140); p:SetFrameStrata("DIALOG")
		if p.TitleText then p.TitleText:SetText(L.HEAD_RECRUIT) end
		local text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("TOP", 0, -32); text:SetText(L.RECRUIT_PROMPT)
		local post = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
		post:SetSize(130, 22); post:SetPoint("BOTTOMLEFT", 16, 12); post:SetText(L.RECRUIT_POST)
		post:SetScript("OnClick", function()   -- a click: the post
			local msg, ch = RC.Prepare(ns.char.recruitTemplate or 1, ns.char.recruitChannel or 2)
			if msg then SendChatMessage(msg, "CHANNEL", nil, ch); RC.Posted() end
			p:Hide()
		end)
		local later = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
		later:SetSize(130, 22); later:SetPoint("BOTTOMRIGHT", -16, 12); later:SetText(L.RECRUIT_LATER)
		later:SetScript("OnClick", function() RC.Snooze() end)
		RC.prompt, RC.promptPost, RC.promptLater = p, post, later
	end
	RC.prompt:Show()
	ns.Screen(L.RECRUIT_PROMPT)
end

function RC.Tick()
	if not ns.char.recruitRemind or not R.IAmOfficer() then return end
	if RC.Wait() > 0 or time() < snoozeUntil then return end
	if RC.prompt and RC.prompt:IsShown() then return end
	RC.ShowPrompt()
end
ns.On("LM_WORLD", function() if not RC.ticker then RC.ticker = C_Timer.NewTicker(30, RC.Tick) end end)
```

README (both languages): the Recruit tab for officers (`/lm reclutar`): three shared templates with placeholders, channel 2 or 1, a 10-minute wait shared by officers, and the 10-minute reminder that offers a one-click Publish. CHANGELOG: one line with the new kinds `rt`, `rc`.

- [ ] **Step 4: Run** test and `npm test`. **Step 5: Commit** — `feat(recruit): the reminder prompt and docs`.
