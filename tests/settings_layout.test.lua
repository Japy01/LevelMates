-- the options pages, tidied: section headers on each page; one dropdown for my role, the language and the transport
-- (not a checkbox per choice); a slider for the book's size
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local S, L, B = ns.Settings, ns.L, ns.Board
local function named(name) for _, s in ipairs(S.AllSettings()) do if s.name == name then return s end end end
-- headers: a few on each page, in order
local function headers(page)
	local out = {}
	for _, i in ipairs(page.layout and page.layout.inits or {}) do if i.header then out[#out + 1] = i.header end end
	return out
end
assert(#headers(S.pages[1]) >= 4 and headers(S.pages[1])[1] == L.OPT_H_ME and headers(S.pages[1])[2] == L.OPT_H_BOOK, "General's headers: " .. table.concat(headers(S.pages[1]), ","))
assert(#headers(S.pages[2]) >= 4 and #headers(S.pages[3]) >= 2, "Share and Notices have headers")
-- dropdowns, with their choices
local role = named(L.OPT_ROLE)
assert(role and role.dropdown and #role.options() == 3 and role.options()[1].value == "T" and role.options()[1].label == L.ROLE_T, "my role as a dropdown")
role:SetValue("H")
assert(ns.Roles.Mine() == "H" and role:GetValue() == "H", "the role set through it")
local lang = named(L.OPT_LANGUAGE)
assert(lang and lang.dropdown and #lang.options() == 3 and lang:GetValue() == "auto", "the language as a dropdown")
local transport = named(L.OPT_TRANSPORT)
assert(transport and transport.dropdown and #transport.options() == 3, "the transport as a dropdown")
assert(not named(L.OPT_ROLE_T) and not named(L.OPT_LANGUAGE .. ": English") and not named(L.OPT_SIZE .. ": " .. L.SIZE_BIG), "no checkbox per choice any more")
-- the size as a slider
local size = named(L.OPT_SIZE)
assert(size and size.slider and size.slider.min == 80 and size.slider.max == 150, "the size as a slider")
B.Toggle()
size:SetValue(120)
assert(ns.db.settings.boardScale == 120 and math.abs(B.frame:GetScale() - 1.2) < 0.001, "the slider scales the book")
