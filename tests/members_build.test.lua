-- Guild > Members: a member's menu opens their build in the talent viewer, any class (mine too)
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L = ns.Board, ns.Comm, ns.L
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function pick(text) for _, e in ipairs(entries) do if e.text == text then return e end end end
B.Toggle()
STUB.Receive("LVLM2", C.Encode("hb", { l = 22, z = 1412, c = "MAGE" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("tb", { c = "MAGE", s = 62, l = 22, p = "2001:11", b = "CODEana" }), "GUILD", "Ana-Testrealm")
B.OpenMemberMenu({ name = "Ana" })
local view = pick(L.CLASS_VIEW_BUILD)
assert(view, "View build for a mage (I am a warrior)")
view.cb()
assert(ns.TalentView.frame:IsShown() and ns.TalentView.entry.name == "Ana", "her build in the viewer")
-- no build shared: no button
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412, c = "ROGUE" }), "GUILD", "Luis-Testrealm")
B.OpenMemberMenu({ name = "Luis" })
assert(not pick(L.CLASS_VIEW_BUILD), "nothing to view")
