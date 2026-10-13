-- the market refuses what cannot be traded: bind-on-pickup and quest items, and an item whose every copy in my bags is
-- already bound; "don't know" never counts as unbound when another source says bound
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GF, L = ns.Gifts, ns.L
local bind = { [7001] = 1, [7002] = 4, [7003] = 2, [7004] = 2, [7005] = 2 }   -- 1 pickup, 4 quest, 2 equip
C_Item.GetItemInfo = function(x)
	local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)") or "")
	if not bind[id] then return nil end
	return "Item " .. id, "|cff1eff00|Hitem:" .. id .. "::::|h[Item " .. id .. "]|h|r", 2, 20, 15, "Armor", "Mail", 1, "INVTYPE_CHEST", 1, 100, 4, 1, bind[id]
end
-- bags: 7003 one copy bound; 7004 one bound and one free; 7005 bound only by the second check
local bags = { [0] = { { itemID = 7003, isBound = true }, { itemID = 7004, isBound = true }, { itemID = 7004, isBound = false }, { itemID = 7005, isBound = false } } }
C_Container = {
	GetContainerNumSlots = function(bag) return bags[bag] and #bags[bag] or 0 end,
	GetContainerItemInfo = function(bag, slot) return bags[bag] and bags[bag][slot] end,
}
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
C_Item.IsBound = function(loc) local i = bags[loc.bag][loc.slot]; return i.itemID == 7005 end
C_Item.DoesItemExist = function() return true end

local function link(id) return "|cff1eff00|Hitem:" .. id .. "::::|h[Item " .. id .. "]|h|r" end
assert(not GF.Add(link(7001)) and (STUB.printed[#STUB.printed] or ""):find(L.GIFT_BOUND, 1, true), "bind on pickup: refused, said why")
assert(not GF.Add(link(7002)), "quest item: refused")
assert(not GF.Add(link(7003)), "my only copy is bound: refused")
assert(GF.Add(link(7004)), "one free copy: offered")
assert(not GF.Add(link(7005)), "bound by the second source: refused")
bind[7006] = 2
assert(GF.Add(link(7006)), "not in my bags (the bank?): offered")
