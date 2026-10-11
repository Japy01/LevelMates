-- The panel's "Defaults" button must restore the shipped defaults, not whatever is set now.
LevelMatesDB = { version = 1, settings = { share = false, sharePos = true, sound = false }, chars = {} }
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
assert(type(ns.DEFAULTS) == "table" and ns.DEFAULTS.share == true, "defaults exported by Core")
local checked = 0
for _, s in ipairs(ns.Settings.AllSettings()) do
	if s.key and ns.DEFAULTS[s.key] ~= nil then
		assert(s.default == ns.DEFAULTS[s.key], s.key .. " default is " .. tostring(s.default) .. ", should be " .. tostring(ns.DEFAULTS[s.key]))
		checked = checked + 1
	end
end
assert(checked >= 8, "checked the boolean switches, got " .. checked)
assert(ns.db.settings.share == false and ns.db.settings.sharePos == true, "saved choices untouched")
assert(ns.L.OPT_MINIMAP_TT and #ns.L.OPT_MINIMAP_TT > 0, "minimap option has a tooltip")
