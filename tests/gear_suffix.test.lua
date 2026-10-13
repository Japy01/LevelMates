-- items with a random suffix ("of the Bear"): the suffix travels with the gear, so their name and stats show right;
-- older versions still read the rest
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local C, GE = ns.Comm, ns.Gear

-- read from my own links: item:id:enchant:gems x4:suffix
STUB.gear[5] = "|cff1eff00|Hitem:9005:0:0:0:0:0:-1043:12345:20|h[Chaleco del oso]|h|r"
STUB.gear[1] = "|cff1eff00|Hitem:9001:15:0:0:0:0:0:0:20|h[Casco]|h|r"
GE.Read()
local s = GE.Mine().slots
assert(s[5].sf == -1043 and (s[1].sf or 0) == 0, "suffix read: " .. tostring(s[5].sf))
local text = GE.Encode(s)
assert(text:match("^[%d:,]*$"), "still digits only (older versions check that)")
local back = GE.Decode(text)
assert(back[5].sf == -1043 and back[5].id == 9005 and back[1].en == 15 and (back[1].sf or 0) == 0, "round trip")
-- an older version's reading of the new text: same items
local old = {}
for slot, id in text:gmatch("(%d+):(%d+):(%d+):(%d+)") do old[tonumber(slot)] = tonumber(id) end
assert(old[5] == 9005 and old[1] == 9001, "older versions read the same items")
-- the old text still reads
assert(GE.Decode("1:9001:33:0")[1].id == 9001, "the old format")

-- the gear window's tooltip asks for the item with its suffix
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("eq", { g = GE.Encode({ [5] = { id = 9005, il = 20, en = 0, sf = -1043 } }), a = 20, r = 1, x = 2 }), "GUILD", "Mario-Testrealm")
ns.GearWindow.Open("Mario")
local b = ns.GearWindow.slots[5]
b.scripts.OnEnter(b)
assert(GameTooltip.link == "item:9005:0:0:0:0:0:-1043", "tooltip with the suffix: " .. tostring(GameTooltip.link))
