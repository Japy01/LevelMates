STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
assert(ns.Settings and ns.Settings.category, "category registered")
local names = {}
for _, s in ipairs(ns.Settings.category.settings) do names[#names + 1] = s.name end
assert(#names >= 9, "all switches registered: " .. #names)
-- toggling share stops/starts comm
local share
for _, s in ipairs(ns.Settings.category.settings) do if s.name == ns.L.OPT_SHARE then share = s end end
share:SetValue(false)
assert(ns.db.settings.share == false and ns.Comm.IsReady() == false, "share off stops comm")
share:SetValue(true)
assert(ns.Comm.IsReady() == true, "share on starts comm")
