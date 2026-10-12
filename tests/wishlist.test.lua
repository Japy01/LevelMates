STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, W, R, L = ns.Comm, ns.Wishlist, ns.Roster, ns.L
local function mate(name) STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function last() return C.Decode(STUB.sent[#STUB.sent].msg) end
local function link(id, name) return "|cff1eff00|Hitem:" .. id .. "::::::::20:::::::|h[" .. (name or ("Item " .. id)) .. "]|h|r" end
local function loot(l) STUB.Fire("CHAT_MSG_LOOT", "You receive loot: " .. l .. ".", "Tester", "", "", "Tester", "", 0, 0, "", 0, 1, "Player-1-TESTER") end
local function said(text) for i = #STUB.printed, 1, -1 do if STUB.printed[i]:find(text, 1, true) then return true end end; return false end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()
assert(ns.db.settings.wishNotices == true, "notices on by default")

-- wire format
assert(C.Validate("wl", {}) and C.Validate("wl", { ids = "123" }) and C.Validate("wl", { ids = 123 }) and C.Validate("wl", { ids = "1,2,3,4,5,6,7,8,9,10" }), "wl format")
assert(C.Validate("wl", { ids = "1,2,3,4,5,6,7,8,9,10,11" }) == false and C.Validate("wl", { ids = "0" }) == false, "wl count and range")
assert(C.Validate("wl", { ids = "1,,2" }) == false and C.Validate("wl", { ids = "1000000" }) == false and C.Validate("wl", { ids = "1," }) == false, "wl pieces")

-- adding and removing
assert(W.ItemId(link(2589)) == 2589 and W.ItemId("hello") == nil, "item ids from links")
assert(W.Add(link(2589)) and W.Has(2589), "added")
local k, f = last()
assert(k == "wl" and tostring(f.ids) == "2589", "told the guild")
assert(W.Add(link(1001)) and select(2, last()).ids == "2589,1001", "the whole list each time")
assert(not W.Add(link(2589)) and said(L.WISH_DUP), "no duplicates")
assert(not W.Add("hello") and said(L.WISH_NOT_ITEM), "not an item")
for id = 3001, 3008 do assert(W.Add(link(id)), "add " .. id) end
assert(not W.Add(link(3009)) and said(string.format(L.WISH_FULL, W.MAX)), "at most 10")
assert(#W.List() == 10 and W.List()[1].mine and W.List()[1].id == 2589 and W.List()[1].name == "Tester", "mine, in order")
for id = 3001, 3008 do assert(W.Remove(id)) end
assert(W.Remove(1001) and not W.Has(1001) and not W.Remove(1001), "removed once")

-- guildmates' lists
mate("Mario"); mate("Ana")
STUB.Receive("LVLM2", C.Encode("wl", { ids = "1001,2589" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("wl", { ids = "1001" }), "GUILD", "Nadie-Testrealm")
local names = W.WantedBy(1001)
assert(#names == 1 and names[1] == "Mario", "Mario wants it; strangers are ignored")
names = W.WantedBy(2589)
assert(#names == 2 and names[1] == "Mario" and names[2] == "Tester", "mine counts too")
assert(#W.List() == 3 and W.List()[2].name == "Mario" and W.List()[2].id == 1001, "then others' wishes")

-- tooltip line
local line
GameTooltip.AddLine = function(self, t) line = t end
STUB.TooltipPost(Enum.TooltipDataType.Item, GameTooltip, { id = 1001 })
assert(line == string.format(L.WISH_TOOLTIP, "Mario"), "tooltip: who wants it")
line = nil
STUB.TooltipPost(Enum.TooltipDataType.Item, GameTooltip, { id = 4242 })
assert(line == nil, "nobody wants it: no line")

-- looting a guildmate's wish: told once per session
loot(link(1001, "Cool Sword"))
assert(said(string.format(L.WISH_THEY_WANT, "Mario", link(1001, "Cool Sword"))), "Mario wants it")
local count = #STUB.printed
loot(link(1001, "Cool Sword"))
assert(#STUB.printed == count, "told once")

-- looting my own wish: got it, removed, the guild told
loot(link(2589))
assert(not W.Has(2589) and said(string.format(L.WISH_GOT, link(2589))) and (last()) == "wl", "got mine")

-- notices off
ns.db.settings.wishNotices = false
STUB.Receive("LVLM2", C.Encode("wl", { ids = "5555" }), "GUILD", "Ana-Testrealm")
count = #STUB.printed
loot(link(5555))
assert(#STUB.printed == count, "notices off: silent")
ns.db.settings.wishNotices = true

-- withdrawn, forgotten, left the guild
STUB.Receive("LVLM2", C.Encode("wl", {}), "GUILD", "Mario-Testrealm")
assert(#W.WantedBy(1001) == 0, "Mario withdrew his list")
ns.db.wishes[GetGuildInfo("player")].Ana.t = time() - 31 * 86400
assert(#W.WantedBy(5555) == 0, "forgotten after 30 days")
STUB.Receive("LVLM2", C.Encode("wl", { ids = "5555" }), "GUILD", "Ana-Testrealm")
STUB.guildMembers = { Tester = true, Mario = true, Luis = true }; R.InvalidateGuildRoster()
assert(#W.WantedBy(5555) == 0, "someone who left the guild is not shown")
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }; R.InvalidateGuildRoster()

-- item links: known, or asked for
STUB.items[1001] = link(1001, "Cool Sword")
assert(W.Link(1001) == link(1001, "Cool Sword"), "a known item")
assert(W.Link(4242) == nil and STUB.itemLoads[4242], "an unknown one is asked for")
local changed = 0
ns.On("LM_WISHES_CHANGED", function() changed = changed + 1 end)
STUB.itemLoads[4242]()
assert(changed == 1, "refresh when it arrives")

-- newcomers get my list
assert(W.Add(link(7777)))
local n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("ping", {}), "GUILD", "Luis-Testrealm"); STUB.Advance(6)
local got = false
for i = n + 1, #STUB.sent do local kk, ff = C.Decode(STUB.sent[i].msg); if kk == "wl" and tostring(ff.ids) == "7777" then got = true end end
assert(got, "a newcomer gets my list")

-- a refused send stays pending in the saved data and goes out after the next heartbeat
STUB.inInstance = true
assert(W.Remove(7777) and LevelMatesDB.chars[ns.PlayerKey()].wishPending == true, "refused inside: pending, saved")
STUB.inInstance = false
ns.Fire("LM_HB_SENT")
k, f = last()
assert(k == "wl" and f.ids == nil and not LevelMatesDB.chars[ns.PlayerKey()].wishPending, "goes out after the heartbeat")
