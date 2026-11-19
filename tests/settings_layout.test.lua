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
local function page(name)
	for _, candidate in ipairs(S.pages) do if candidate.name == name then return candidate end end
end
assert(#headers(page(L.OPT_PAGE_SHARE)) >= 4 and #headers(page(L.OPT_PAGE_NOTICES)) >= 2, "Share and Notices have headers")
assert(headers(page(L.OPT_H_GUILD))[1] == L.TAB_ANNOUNCEMENTS)
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


-- The permissions control is registered even when roster data arrives after login.
local policy = named(L.OPT_ANNOUNCEMENT_PERMISSIONS)
assert(policy and policy.dropdown, "the guild settings page exposes a native moderation control")
STUB.guildMembers = { Tester = true, Mario = true }
STUB.memberInfo = { Tester = {rank = 1, rankName = "Master"}, Mario = {rank = 2, rankName = "Officer"} }
STUB.guildRoles = { Tester = 2, Mario = 2 }
ns.Roster.InvalidateGuildRoster()
policy:SetValue("2")
assert(not ns.Sync.Get("gam", "moderation"), "an officer cannot change moderation")
STUB.guildRoles.Tester = 1
ns.Roster.InvalidateGuildRoster()
assert(#policy.options() == 2, "the master sees the guild's verified ranks")
policy:SetValue("2")
assert(ns.Sync.Get("gam", "moderation").d.r == 2, "the master can delegate moderation")
