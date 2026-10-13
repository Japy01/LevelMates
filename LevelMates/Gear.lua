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

-- "slot:id:ilvl:enchant,…"
function GE.Encode(slots)
	local parts = {}
	for slot = 1, 19 do
		local s = slots[slot]
		if s then parts[#parts + 1] = slot .. ":" .. s.id .. ":" .. (s.il or 0) .. ":" .. (s.en or 0) end
	end
	return table.concat(parts, ",")
end
function GE.Decode(g)
	if type(g) ~= "string" then return nil end
	local out = {}
	for slot, id, il, en in g:gmatch("(%d+):(%d+):(%d+):(%d+)") do
		slot = tonumber(slot)
		if slot >= 1 and slot <= 19 then out[slot] = { id = tonumber(id), il = tonumber(il), en = tonumber(en) } end
	end
	return out
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
function GE.Read()
	local slots = {}
	for slot = 1, 19 do
		local link = GetInventoryItemLink("player", slot)
		local id, en = tostring(link or ""):match("item:(%d+):(%d*)")
		if id then slots[slot] = { id = tonumber(id), il = itemLevel(link), en = tonumber(en) or 0 } end
	end
	GE.reads = GE.reads + 1
	local avg, filled = GE.Average(slots)
	local _, _, race = UnitRace("player")
	local old = ns.char.gear
	ns.char.gear = { slots = slots, avg = avg, filled = filled, r = race, x = UnitSex("player"), t = time() }
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
	theirs()[name] = { slots = slots, avg = avg, filled = filled, r = f.r, x = f.x, t = time() }
	ns.Fire("LM_GEAR_CHANGED", name)
end)
function GE.Of(name)
	if name == ns.Me() then return GE.Mine() end
	return theirs()[name]
end

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
