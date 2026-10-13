-- a crafter's recipes in order: by kind (the slot it is worn on, else the kind of item), then level, then name, with a
-- heading row per kind; "only tradable" hides what binds on pickup; "who else crafts it?" from a recipe; late item
-- names redraw the list (once for a burst)
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L, RC, P = ns.Board, ns.Comm, ns.L, ns.Recipes, ns.Professions
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
INVTYPE_CHEST, INVTYPE_HAND = "Pecho", "Manos"
-- id: name, required level, kind, slot, bind (1 pickup, 2 equip)
local info = {
	[2300] = { "Jubón repujado", 10, "Armadura", "INVTYPE_CHEST", 2 },
	[2310] = { "Jubón ligero", 5, "Armadura", "INVTYPE_CHEST", 2 },
	[2312] = { "Guantes finos", 12, "Armadura", "INVTYPE_HAND", 1 },
	[2304] = { "Kit de armadura", 1, "Consumible", "", 0 },
}
local known = { [2300] = true, [2310] = true, [2312] = true, [2304] = true }
C_Item.GetItemInfo = function(x)
	local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)") or "")
	local i = id and info[id]
	if not i or not known[id] then return nil end
	return i[1], "|cff1eff00|Hitem:" .. id .. "|h[" .. i[1] .. "]|h|r", 2, 20, i[2], i[3], "", 1, i[4], 133000, 10, 4, 0, i[5]
end
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", "Ana-Testrealm")
P.AddSample("Mario", { { id = 165, rank = 138, max = 225 } })
P.AddSample("Ana", { { id = 165, rank = 100, max = 150 } })
STUB.Receive("LVLM2", C.Encode("rcp", { p = 165, r = 138, m = 225, i = RC.Encode({ 2300, 2304, 2310, 2312 }) }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("rcp", { p = 165, r = 100, m = 150, i = RC.Encode({ 2300 }) }), "GUILD", "Ana-Testrealm")
B.Toggle(); B.ShowTab("crafts")
local CV = ns.CraftsView
CV.Select(165)
for _, r in ipairs(CV.rows) do if r:IsShown() and r.name.text == "Mario" then r.scripts.OnClick(r) end end
assert(CV.mode == "recipes", "Mario's recipes")
local function shown()
	local out = {}
	for _, r in ipairs(CV.rows) do if r:IsShown() then out[#out + 1] = (r.header and "# " or "") .. r.name.text end end
	return table.concat(out, " | ")
end
assert(shown() == "# Consumible | Kit de armadura | # Manos | Guantes finos | # Pecho | Jubón ligero | Jubón repujado", "in order: " .. shown())
-- only tradable
assert(CV.tradable and CV.tradable:IsShown(), "the box")
CV.tradable:SetChecked(true); CV.tradable.scripts.OnClick(CV.tradable)
assert(not shown():find("Guantes finos", 1, true) and not shown():find("# Manos", 1, true), "bind on pickup hidden, and its empty heading: " .. shown())
assert(ns.db.settings.craftsTradable == true, "remembered")
CV.tradable:SetChecked(false); CV.tradable.scripts.OnClick(CV.tradable)
-- who else crafts it
local vest
for _, r in ipairs(CV.rows) do if r:IsShown() and r.name.text == "Jubón repujado" then vest = r end end
vest.scripts.OnClick(vest)
local other
for _, e in ipairs(entries) do if e.text == L.CV_WHO_ELSE then other = e end end
assert(other, "who else crafts it")
other.cb()
assert(CV.mode == "search" and shown():find("Jubón repujado", 1, true), "the search: " .. shown())
-- late names: one redraw for a burst
CV.Select(165)
for _, r in ipairs(CV.rows) do if r:IsShown() and r.name.text == "Mario" then r.scripts.OnClick(r) end end
known[2312] = nil
local n = CV.redraws or 0
for _ = 1, 20 do STUB.Fire("GET_ITEM_INFO_RECEIVED", 2312, true) end
STUB.Advance(1)
assert((CV.redraws or 0) - n >= 1 and (CV.redraws or 0) - n <= 3, "a few redraws for the burst, not one each: " .. tostring((CV.redraws or 0) - n))
