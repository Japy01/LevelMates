STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
assert(ns.Settings and ns.Settings.category, "category registered")
local names = {}
for _, s in ipairs(ns.Settings.AllSettings()) do names[#names + 1] = s.name end
assert(#names >= 9, "all switches registered: " .. #names)
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, R = ns.Comm, ns.Roster
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421 }), "GUILD", "Mario-Testrealm")
assert(#R.List() == 1, "mate known")
-- toggling share off stops comm, forgets everyone and refuses to send
local share
for _, s in ipairs(ns.Settings.AllSettings()) do if s.name == ns.L.OPT_SHARE then share = s end end
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
assert(table.concat(kinds, ",") == "eq,hb,hi", "re-announced after share on (with my gear): " .. table.concat(kinds, ","))

-- three pages: general, share, notices
assert(#ns.Settings.pages == 3 and ns.Settings.pages[2].name == ns.L.OPT_PAGE_SHARE and ns.Settings.pages[3].name == ns.L.OPT_PAGE_NOTICES, "three pages")
local function on(page, key) for _, s in ipairs(page.settings) do if s.key == key then return true end end end
assert(on(ns.Settings.pages[1], "share") and on(ns.Settings.pages[2], "sharePos") and on(ns.Settings.pages[3], "helpNotices"), "each switch on its page")

-- quiet mode: the lesser notices off, back as they were
local S = ns.Settings
ns.db.settings.rareNotices = false   -- my own choice before
S.SetQuiet(true)
assert(S.IsQuiet() and not ns.db.settings.levelNotices and not ns.db.settings.screenNotices and not ns.db.settings.sound, "quiet")
assert(ns.db.settings.helpNotices and ns.db.settings.lfgNotices and ns.db.settings.goalNotices, "help, groups and goals stay")
S.SetQuiet(false)
assert(not S.IsQuiet() and ns.db.settings.levelNotices and ns.db.settings.sound and ns.db.settings.rareNotices == false, "back as they were")
