-- Builds.lua: talent builds shared with the guild in kind `tb` (class, spec, level, points per branch and, once the
-- game can give it, the build code). The Class tab lists the ones of my class; "View build" opens the game's own
-- build viewer from a click. Spec 2026-10-10-levelmates-class-tanda-design.
local _, ns = ...
local BU = {}
ns.Builds = BU
local L, C, R = ns.L, ns.Comm, ns.Roster
BU.FORGET_DAYS = 30

local function me() return (UnitName("player")) end
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
		if g.groupID then out[#out + 1] = { id = g.groupID, name = g.displayName or ("#" .. g.groupID) } end
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

-- The build code: the game gives it once its talent window has been open this session; never an error.
local function code()
	local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
	if not (tf and tf.GetLoadoutExportString) then return nil end
	local ok, s = pcall(tf.GetLoadoutExportString, tf)
	if ok and type(s) == "string" and #s <= 150 and s:match("^[%w%+/=]+$") then return s end
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
for _, e in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP", "ADDON_LOADED" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" then
		if arg == "Blizzard_PlayerSpells" and PlayerSpellsFrame and PlayerSpellsFrame.HookScript then PlayerSpellsFrame:HookScript("OnHide", soon) end
		return
	end
	soon()
end)
ns.On("LM_ANNOUNCED", function() announced = true; if fields().p then send() else lastSent = key({}) end end)   -- nothing to share: nothing sent
ns.On("LM_PING_ANSWERED", function() if fields().p then send() end end)
ns.On("LM_HB_SENT", function() if ns.char.buildPending then send() end end)
ns.On("LM_COMM_DROPPED", function(kind) if kind == "tb" then ns.char.buildPending = true end end)

C.OnMessage("tb", function(f, name)
	if not R.mates[name] then return end
	local t = store()
	if f.p == nil then t[name] = nil
	else t[name] = { c = f.c, s = f.s, l = f.l, p = f.p, b = f.b, t = time() } end
	ns.Fire("LM_BUILDS_CHANGED")
end)

local function fresh(name, e)
	return e.t >= time() - BU.FORGET_DAYS * 86400 and e.c == myClass() and name ~= me() and (e.sim or R.IsGuildmate(name))
end

-- A guildmate's build, when they are of my class.
function BU.Of(name)
	local e = store()[name]
	if e and fresh(name, e) then return e end
end

-- Mine first, then guildmates of my class (highest level first).
function BU.List(search)
	local q, out, others = (search or ""):lower(), {}, {}
	local m = BU.Mine()
	if m.p and (q == "" or me():lower():find(q, 1, true)) then out[1] = { name = me(), c = m.c, s = m.s, l = m.l, p = m.p, b = m.b, mine = true } end
	for name, e in pairs(store()) do
		if e.t < time() - BU.FORGET_DAYS * 86400 then store()[name] = nil
		elseif fresh(name, e) and (q == "" or name:lower():find(q, 1, true)) then
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
	for id, n in tostring(e.p or ""):gmatch("(%d+):(%d+)") do parts[#parts + 1] = (names[tonumber(id)] or ("#" .. id)) .. " " .. n end
	return table.concat(parts, " / ")
end

-- The game's build viewer. Runs only from a click (menu entry).
function BU.Open(e)
	if not (e and e.b and e.s and e.l) then return false end
	local opts = e.s .. ":" .. e.l .. ":" .. e.b
	local link = "|Htalentbuild:" .. opts .. "|h[" .. L.BUILD_LINK .. "]|h"
	pcall(SetItemRef, "talentbuild:" .. opts, link, "LeftButton")
	return true
end

function BU.AddSample(name, e) e.t, e.sim = time(), true; store()[name] = e; ns.Fire("LM_BUILDS_CHANGED") end
function BU.RemoveSamples()
	local t = store()
	for name, e in pairs(t) do if e.sim then t[name] = nil end end
	ns.Fire("LM_BUILDS_CHANGED")
end
