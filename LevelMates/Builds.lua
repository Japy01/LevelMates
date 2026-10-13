-- Builds.lua: talent builds shared with the guild in kind `tb` (class, spec, level, points per branch and, once the
-- game can give it, the build code). The Class tab lists the ones of my class; "View build" opens the game's own
-- build viewer from a click. Spec 2026-10-10-levelmates-class-tanda-design.
local _, ns = ...
local BU = {}
ns.Builds = BU
local L, C, R = ns.L, ns.Comm, ns.Roster
BU.FORGET_DAYS = 30

local function me() return ns.Me() end
local function myClass() return select(2, UnitClass("player")) end
local function store()
	ns.db.builds = ns.db.builds or {}
	local k = GetGuildInfo("player") or "?"
	ns.db.builds[k] = ns.db.builds[k] or {}
	return ns.db.builds[k]
end

-- My active talent tree (Forever: one tree whose branches are groups). Every call is guarded: nil when the client
-- has no such API or no talents yet.
local function tree()
	if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits) then return end
	local ok, cfg = pcall(C_ClassTalents.GetActiveConfigID)
	if not ok or not cfg then return end
	local ok2, info = pcall(C_Traits.GetConfigInfo, cfg)
	local treeId = ok2 and info and info.treeIDs and info.treeIDs[1]
	if treeId then return cfg, treeId end
end

-- The branches of my tree, in the game's order: { { id, name } }.
function BU.Groups()
	local cfg, treeId = tree()
	if not cfg then return {} end
	local ok, groups = pcall(C_Traits.GetGroupDisplayInfoByTreeID, treeId)
	local out = {}
	for _, g in ipairs(ok and groups or {}) do
		if g.groupID then   -- Forever names them "Tree 1": the classic names of my class instead
			local name = ns.Talents and ns.Talents.BranchName(myClass(), { name = g.displayName }, #out + 1) or g.displayName
			out[#out + 1] = { id = g.groupID, name = name or ("#" .. g.groupID) }
		end
	end
	return out
end

local function points()
	local cfg = tree()
	local groups = BU.Groups()
	if not cfg or #groups == 0 then return nil end
	local ids = {}
	for _, g in ipairs(groups) do ids[#ids + 1] = g.id end
	local ok, infos = pcall(C_Traits.GetGroupCurrencyInfo, cfg, ids)
	local spentBy = {}
	for _, gi in ipairs(ok and infos or {}) do
		local c = gi.currencyInfos and gi.currencyInfos[1]
		if gi.traitNodeGroupID then spentBy[gi.traitNodeGroupID] = c and c.spent or 0 end
	end
	local parts = {}
	for _, g in ipairs(groups) do parts[#parts + 1] = g.id .. ":" .. math.max(0, math.floor(spentBy[g.id] or 0)) end
	return table.concat(parts, ",")
end

-- The build code: made from the talent API (Talents.lua), never by asking the game's talent window (that taints it).
local function code()
	local s = ns.Talents and ns.Talents.MyCode and ns.Talents.MyCode()
	if type(s) == "string" and #s <= 150 and s:match("^[%w%+/=]+$") then return s end
end

function BU.Mine()
	local spec = PlayerUtil and PlayerUtil.GetCurrentSpecID and select(2, pcall(PlayerUtil.GetCurrentSpecID))
	return { c = myClass(), s = tonumber(spec) or 0, l = UnitLevel("player"), p = points(), b = code() }
end

local function fields()
	local m = BU.Mine()
	if not ns.db.settings.shareBuild or not m.p then return {} end
	return { c = m.c, s = m.s, l = m.l, p = m.p, b = m.b }
end
local function key(f) return table.concat({ f.c or "", f.s or "", f.l or "", f.p or "", f.b or "" }, "|") end

local lastSent, announced
local function send(prio)
	local f = fields()
	if C.Send("tb", f, prio) then ns.char.buildPending, lastSent = nil, key(f); return true end
	ns.char.buildPending = true
	return false
end
local function sendIfChanged() if announced and key(fields()) ~= lastSent then send() end end

function BU.SetSharing() send("now") end

-- A talent change, a level or the talent window closing: once things settle (respeccing fires many events).
local scheduled
local function soon()
	if scheduled then return end
	scheduled = true
	C_Timer.After(5, function() scheduled = false; sendIfChanged() end)
end
local events = CreateFrame("Frame")
for _, e in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP", "ADDON_LOADED" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" then
		if arg == "Blizzard_PlayerSpells" and PlayerSpellsFrame and PlayerSpellsFrame.HookScript then PlayerSpellsFrame:HookScript("OnHide", soon) end
		return
	end
	soon()
end)
ns.On("LM_ANNOUNCED", function() announced = true; if fields().p then send() else lastSent = key({}) end end)   -- nothing to share: nothing sent
ns.On("LM_HELLO_ANSWERED", function() if fields().p then send() end end)
ns.On("LM_HB_SENT", function() if ns.char.buildPending then send() end end)
ns.On("LM_COMM_DROPPED", function(kind) if kind == "tb" then ns.char.buildPending = true end end)

C.OnMessage("tb", function(f, name)
	local m = R.mates[name]
	if not m then return end
	local t = store()
	if f.p == nil then t[name] = nil
	elseif type(f.l) == "number" and type(f.s) == "number" then   -- the class is the roster's, not what the message claims
		t[name] = { c = m.class or f.c, s = f.s, l = f.l, p = f.p, b = f.b, t = time() }
	else return end
	ns.Fire("LM_BUILDS_CHANGED")
end)

-- Any class (cards show everyone's build); the Class tab keeps to mine (BU.List).
local function fresh(name, e)
	return e.t >= time() - BU.FORGET_DAYS * 86400 and name ~= me() and (e.sim or R.IsGuildmate(name))
end

-- A guildmate's build, of any class.
function BU.Of(name)
	local e = store()[name]
	if e and fresh(name, e) then return { name = name, c = e.c, s = e.s, l = e.l, p = e.p, b = e.b, t = e.t } end
end

-- Mine first, then guildmates of my class (highest level first).
function BU.List(search)
	local q, out, others = (search or ""):lower(), {}, {}
	local m = BU.Mine()
	if m.p and (q == "" or me():lower():find(q, 1, true)) then out[1] = { name = me(), c = m.c, s = m.s, l = m.l, p = m.p, b = m.b, mine = true } end
	for name, e in pairs(store()) do
		if e.t < time() - BU.FORGET_DAYS * 86400 then store()[name] = nil
		elseif fresh(name, e) and e.c == myClass() and (q == "" or name:lower():find(q, 1, true)) then
			others[#others + 1] = { name = name, c = e.c, s = e.s, l = e.l, p = e.p, b = e.b, t = e.t }
		end
	end
	table.sort(others, function(a, b) if a.l ~= b.l then return a.l > b.l end; return a.name < b.name end)
	for _, o in ipairs(others) do out[#out + 1] = o end
	return out
end

-- "Armas 9 / Furia 0 / Protección 0": branch names from my own tree (same class, same tree).
function BU.PointsText(e)
	local names = {}
	for _, g in ipairs(BU.Groups()) do names[g.id] = g.name end
	local parts = {}
	for id, n in tostring(e.p or ""):gmatch("(%d+):(%d+)") do parts[#parts + 1] = names[tonumber(id)] and (names[tonumber(id)] .. " " .. n) or n end   -- another class: its branch names are not in my tree
	return table.concat(parts, " / ")
end

-- "View build": the build's link in my chat window (only on my screen, nothing is posted). Its click goes through
-- the game's own chat handler, which opens the build viewer; opening that window from addon code could taint it.
function BU.Open(e)
	if not (e and e.b and e.s and e.l) then return false end
	local link = "|cff71d5ff|Htalentbuild:" .. e.s .. ":" .. e.l .. ":" .. e.b .. "|h[" .. string.format(L.BUILD_LINK, e.name or "?") .. "]|h|r"
	ns.Say(L.BUILD_CLICK, link)
	return true
end

function BU.AddSample(name, e) e.t, e.sim = time(), true; store()[name] = e; ns.Fire("LM_BUILDS_CHANGED") end
function BU.RemoveSamples()
	local t = store()
	for name, e in pairs(t) do if e.sim then t[name] = nil end end
	ns.Fire("LM_BUILDS_CHANGED")
end
