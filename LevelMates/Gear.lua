-- Gear.lua: my gear (item, item level and enchant of each slot), read out of combat when it changes, with my own item
-- level average (Forever's GetAverageItemLevel always divides by 16); shared as personal state `eq` with my race and
-- sex for the model. Spec 2026-10-12-levelmates-armory-design (1).
local _, ns = ...
local GE = {}
ns.Gear = GE
local C, R = ns.Comm, ns.Roster
GE.SETTLE = 1
GE.reads = 0
local IGNORED = { [4] = true, [19] = true }   -- shirt and tabard: never part of the average

-- "slot:id:ilvl:enchant[:suffix],…". The suffix (an item's random "of the Bear") goes shifted by SUFFIX_SHIFT, as
-- digits only: older versions check the text is digits, colons and commas, and still read the first four numbers.
GE.SUFFIX_SHIFT = 50000
function GE.Encode(slots)
	local parts = {}
	for slot = 1, 19 do
		local s = slots[slot]
		if s then
			local part = slot .. ":" .. s.id .. ":" .. (s.il or 0) .. ":" .. (s.en or 0)
			if s.sf and s.sf ~= 0 and math.abs(s.sf) < GE.SUFFIX_SHIFT then part = part .. ":" .. (s.sf + GE.SUFFIX_SHIFT) end
			parts[#parts + 1] = part
		end
	end
	return table.concat(parts, ",")
end
function GE.Decode(g)
	if type(g) ~= "string" then return nil end
	local out = {}
	for part in g:gmatch("[^,]+") do
		local slot, id, il, en, sf = part:match("^(%d+):(%d+):(%d+):(%d+):?(%d*)$")
		slot = tonumber(slot)
		if slot and slot >= 1 and slot <= 19 then
			out[slot] = { id = tonumber(id), il = tonumber(il), en = tonumber(en), sf = sf ~= "" and tonumber(sf) - GE.SUFFIX_SHIFT or nil }
		end
	end
	return out
end
-- The item as the game names it, with its enchant and suffix: "item:id:enchant:0:0:0:0:suffix".
function GE.ItemString(s)
	if not s then return nil end
	if s.sf and s.sf ~= 0 then return "item:" .. s.id .. ":" .. (s.en or 0) .. ":0:0:0:0:" .. s.sf end
	return "item:" .. s.id .. ":" .. (s.en or 0)
end
-- Over the filled slots that count (all but shirt and tabard), skipping items whose level is not known yet.
function GE.Average(slots)
	local sum, n = 0, 0
	for slot, s in pairs(slots or {}) do
		if not IGNORED[slot] and (s.il or 0) > 0 then sum = sum + s.il; n = n + 1 end
	end
	return n > 0 and math.floor(sum / n + 0.5) or 0, n
end

local function itemLevel(link)
	local il = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
	if not il then il = select(4, ns.ItemInfo(link)) end
	return tonumber(il) or 0
end
function GE.Mine() return ns.char.gear end
-- A unit's worn items: id, item level, enchant and suffix from each slot's link.
local function slotsOf(unit)
	local slots = {}
	for slot = 1, 19 do
		local link = GetInventoryItemLink(unit, slot)
		local id, en, sf = tostring(link or ""):match("item:(%d+):(%d*):?%-?%d*:?%-?%d*:?%-?%d*:?%-?%d*:?(%-?%d*)")
		if id then slots[slot] = { id = tonumber(id), il = itemLevel(link), en = tonumber(en) or 0, sf = tonumber(sf) ~= 0 and tonumber(sf) or nil } end
	end
	return slots
end
function GE.Read()
	local slots = slotsOf("player")
	GE.reads = GE.reads + 1
	local avg, filled = GE.Average(slots)
	local _, _, race = UnitRace("player")
	local old = ns.char.gear
	ns.char.gear = { slots = slots, avg = avg, filled = filled, r = race, x = UnitSex("player"), t = time(), src = "self" }
	if not old or GE.Encode(old.slots) ~= GE.Encode(slots) then ns.Fire("LM_MY_GEAR_CHANGED"); ns.Fire("LM_GEAR_CHANGED") end
end

-- Sharing: through the personal-state helper (pending while it cannot go; newcomers at most every 10 minutes).
local function gearText(v) return type(v) == "string" and #v <= 600 and v:match("^[%d:,]*$") ~= nil end
C.SCHEMA.eq = { g = gearText, a = C.V.int(0, 999), r = C.V.int(1, 100), x = C.V.int(2, 3) }
C.REQUIRED.eq = { "g" }
local share = ns.Sync.Personal("eq", function()
	local g = GE.Mine()
	if not g then return nil end
	return { g = GE.Encode(g.slots), a = g.avg, r = g.r and g.r >= 1 and g.r <= 100 and g.r or nil, x = (g.x == 2 or g.x == 3) and g.x or nil }
end, { save = "gearPending", helloGap = 600, worth = function() return GE.Mine() ~= nil end,
	enabled = function() return ns.db.settings.shareGear end })
ns.On("LM_MY_GEAR_CHANGED", function() share.Mark() end)   -- mine only: theirs arriving must not echo mine

-- Theirs.
local function theirs()
	ns.db.gear = ns.db.gear or {}
	local g = GetGuildInfo("player") or "?"
	ns.db.gear[g] = ns.db.gear[g] or {}
	return ns.db.gear[g]
end
C.OnMessage("eq", function(f, name)
	local slots = GE.Decode(f.g)
	if not slots then return end
	local avg, filled = GE.Average(slots)
	theirs()[name] = { slots = slots, avg = avg, filled = filled, r = f.r, x = f.x, t = time(), src = "sync" }
	ns.Fire("LM_GEAR_CHANGED", name)
end)
function GE.Of(name)
	if name == ns.Me() then return GE.Mine() end
	return theirs()[name]
end

-- Inspect: the gear of someone the game lets me inspect (my target, my group), LevelMates or not. One request at a
-- time, answered within 8 s; only the answer to my own request counts (another addon or the game's own inspect window
-- may be asking too, and theirs is left alone), and only if that unit is still the same person.
GE.INSPECT_WAIT = 8
local pending
function GE.InspectUnit(name)
	if not (CanInspect and NotifyInspect) or name == ns.Me() then return nil end
	local units = { "target" }
	for i = 1, 4 do units[#units + 1] = "party" .. i end
	for _, u in ipairs(units) do
		if UnitName(u) == name then
			local ok, can = pcall(CanInspect, u)
			if ok and can then return u end
		end
	end
end
local function same(a, b) local ok, eq = pcall(function() return a ~= nil and a == b end); return ok and eq end   -- GUIDs can be hidden values
function GE.Inspect(unit, name)
	if pending and GetTime() - pending.at < GE.INSPECT_WAIT then return false end
	if not (unit and CanInspect and NotifyInspect) then return false end
	local ok, can = pcall(CanInspect, unit)
	if not (ok and can) then return false end
	pending = { unit = unit, name = name, guid = UnitGUID(unit), at = GetTime() }
	NotifyInspect(unit)
	return true
end
local insp = CreateFrame("Frame")
insp:RegisterEvent("INSPECT_READY")
insp:SetScript("OnEvent", function(_, _, guid)
	if not pending or not same(guid, pending.guid) then return end
	local p = pending
	pending = nil
	if not same(UnitGUID(p.unit), p.guid) or UnitName(p.unit) ~= p.name then return end   -- someone else by now
	local slots = slotsOf(p.unit)
	if not next(slots) then return end
	local avg, filled = GE.Average(slots)
	local old = theirs()[p.name]
	theirs()[p.name] = { slots = slots, avg = avg, filled = filled, r = old and old.r, x = old and old.x, t = time(), src = "inspect" }
	ns.Fire("LM_GEAR_CHANGED", p.name)
end)

-- When: the gear changed (quiet for a second), at login, after an item's data arrives; never in combat.
local due, waitingCombat
local function later()
	due = GetTime() + GE.SETTLE
	C_Timer.After(GE.SETTLE + 0.05, function()
		if not due or GetTime() < due then return end
		due = nil
		if InCombatLockdown and InCombatLockdown() then waitingCombat = true; return end
		GE.Read()
	end)
end
local lastInfo = -math.huge
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED"); ev:RegisterEvent("PLAYER_REGEN_ENABLED"); ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then if waitingCombat then waitingCombat = false; later() end; return end
	if event == "GET_ITEM_INFO_RECEIVED" then   -- an item of mine with an unknown level may have arrived: once in a while
		local g = GE.Mine()
		if not g or GetTime() - lastInfo < 2 then return end
		local missing = false
		for _, s in pairs(g.slots) do if (s.il or 0) == 0 then missing = true end end
		if not missing then return end
		lastInfo = GetTime()
	end
	later()
end)
ns.On("LM_WORLD", later)
