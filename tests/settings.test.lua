STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
assert(ns.Settings and ns.Settings.category, "category registered")
local names = {}
for _, s in ipairs(ns.Settings.category.settings) do names[#names + 1] = s.name end
assert(#names >= 9, "all switches registered: " .. #names)
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, R = ns.Comm, ns.Roster
STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1421 }), "GUILD", "Mario-Testrealm")
assert(#R.List() == 1, "mate known")
-- toggling share off stops comm, forgets everyone and refuses to send
local share
for _, s in ipairs(ns.Settings.category.settings) do if s.name == ns.L.OPT_SHARE then share = s end end
share:SetValue(false)
assert(ns.db.settings.share == false and C.IsReady() == false, "share off stops comm")
assert(#R.List() == 0, "share off forgets mates (you see nobody)")
local n = #STUB.sent
assert(C.Send("hb", { l = 1, z = 1 }) == false and #STUB.sent == n, "nothing goes out while off")
-- toggling share on starts comm and announces me again
share:SetValue(true)
assert(C.IsReady() == true, "share on starts comm")
STUB.Advance(1)
local kinds = {}
for i = n + 1, #STUB.sent do kinds[#kinds + 1] = select(1, C.Decode(STUB.sent[i].msg)) end
table.sort(kinds)
assert(table.concat(kinds, ",") == "hb,ping", "re-announced after share on: " .. table.concat(kinds, ","))
