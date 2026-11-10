-- WishlistAlerts.lua: local notices while a personal wish is available to roll on or loot.
local _, ns = ...
local L, W, Plain = ns.L, ns.Wishlist, ns.Plain
local rolls, window = {}, {}

local function options(key)
	if not ns.db or not ns.char then return end
	local settings = ns.db.settings
	if settings[key] and not settings.quietSaved then return settings end
end

local function notify(message, link, settings)
	ns.NoticeAt("wishes", message, link)
	if settings.sound and SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING) end
end

local function rollStarted(rollID, duration)
	local settings = options("wishRollAlerts")
	rollID = Plain(rollID)
	if not settings or type(rollID) ~= "number" or rolls[rollID] then return end

	local link = Plain(GetLootRollItemLink(rollID))
	local id = W.ItemId(link)
	if not id or not W.Has(id) then return end

	local marker = {}
	rolls[rollID] = marker
	duration = Plain(duration)
	C_Timer.After(type(duration) == "number" and duration > 0 and duration / 1000 or 60, function()
		if rolls[rollID] == marker then rolls[rollID] = nil end
	end)
	local canNeed = Plain((select(6, GetLootRollItemInfo(rollID))))
	notify(canNeed == true and L.WISH_ROLL_NEED or L.WISH_ROLL_ALERT, link, settings)
end

local function scanLoot()
	local settings = options("wishLootAlerts")
	if not settings then return end
	local count = Plain(GetNumLootItems())
	if type(count) ~= "number" then return end

	for slot = 1, count do
		local link = Plain(GetLootSlotLink(slot))
		local id = W.ItemId(link)
		if id and not window[id] and W.Has(id) then
			window[id] = true
			notify(L.WISH_LOOT_ALERT, link, settings)
		end
	end
end

local handlers = {
	START_LOOT_ROLL = rollStarted,
	CANCEL_LOOT_ROLL = function(id)
		id = Plain(id)
		if type(id) == "number" then rolls[id] = nil end
	end,
	CANCEL_ALL_LOOT_ROLLS = function() rolls = {} end,
	LOOT_READY = scanLoot,
	LOOT_OPENED = scanLoot,
	LOOT_CLOSED = function() window = {} end,
}
local frame = CreateFrame("Frame")
for event in pairs(handlers) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
