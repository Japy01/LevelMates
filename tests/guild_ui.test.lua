-- Members and Bank sub-tabs; the message of the day on Home
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L = ns.Board, ns.Comm, ns.L
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateRadio = function(_, text, isSel, setSel, data) entries[#entries + 1] = { text = text, radio = true, selected = isSel(data) and true or false, cb = function() setSel(data) end } end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function opt(t) for _, e in ipairs(entries) do if e.text == t then return e end end end
STUB.guildRoles = { Luis = 2 }; ns.Roster.InvalidateGuildRoster()
STUB.memberInfo = { Mario = { level = 30 }, Ana = { level = 25 }, Luis = { level = 40 }, Tester = { level = 20 } }
STUB.guildTotal = 4
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("gn", STUB.Rec{ id = ns.NameKey("Mario"), f = "Mario", n = "Herborista" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("gmo", STUB.Rec{ id = "motd", n = "Raid el viernes" }), "GUILD", "Luis-Testrealm")
STUB.Fire("GUILD_ROSTER_UPDATE"); STUB.Advance(3)
B.Toggle()
-- nine sub-tabs that fit (Ruling 2026-10-16: Loot joined them; the buttons narrowed to 72)
assert(#B.GUILD_KEYS == 9 and B.subs.members and B.subs.bank and B.subs.loot, "members, bank and loot among the sub-tabs")
for _, k in ipairs(B.GUILD_KEYS) do assert(B.subs[k]:GetWidth() <= 72, "narrow: " .. k) end
-- Home: the message of the day first
B.ShowTab("home")
assert(ns.Dashboard.motd:IsShown() and ns.Dashboard.motd.text.text:find("Raid el viernes", 1, true), "the MOTD strip on Home")
-- Members: the list, every member, with notes
B.ShowTab("members")
local mario
for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.memberEntry and r.button.memberEntry.name == "Mario" then mario = r end end
assert(mario and mario.zone.text:find("Herborista", 1, true), "Mario with his note")
local n = 0
for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.memberEntry then n = n + 1 end end
assert(n == 4, "all four members: " .. n)
mario.button.scripts.OnClick(mario.button, "LeftButton")
assert(opt(L.MENU_WHISPER) and opt(L.MENU_INVITE), "whisper and invite")
assert(B.memberFilter == "all"); B.memberFilterButton.scripts.OnClick(B.memberFilterButton); opt(L.MEMBERS_FILTER_ONLINE).cb(); assert(B.memberFilter == "online", "filter: online")
B.memberFilter = "all"; B.Refresh()   -- Ruling 2026-10-17: the stub's members are offline unless a test says otherwise, so the page is redrawn with every member
-- my own row: write my note
local mine
for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.memberEntry and r.button.memberEntry.name == ns.Me() then mine = r end end
mine.button.scripts.OnClick(mine.button, "LeftButton")
assert(opt(L.NOTE_WRITE), "write my note")
-- the views (Mario shares an alt)
STUB.guildMembers.Marito = true; ns.Roster.InvalidateGuildRoster(); ns.Members.Invalidate()
STUB.Receive("LVLM2", C.Encode("al", { n = "Marito" }), "GUILD", "Mario-Testrealm")
local kinds = { historyEntry = L.MEMBERS_VIEW_HISTORY, altEntry = L.MEMBERS_VIEW_ALTS, raceEntry = L.MEMBERS_VIEW_RACE }
for field, label in pairs(kinds) do
	B.memberViewButton.scripts.OnClick(B.memberViewButton); opt(label).cb()
	local any = false
	for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button[field] then any = true end end
	assert(any or field == "historyEntry", "rows for " .. field)
end
-- Bank
STUB.bank = { money = 50000, tabs = { { name = "General", slots = { [1] = { id = 858, n = 4 } } } } }
STUB.Fire("GUILDBANKFRAME_OPENED"); STUB.Advance(3); STUB.Fire("GUILDBANKFRAME_CLOSED"); STUB.Advance(2)
B.ShowTab("bank")
local item = false
for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.bankEntry and r.button.bankEntry.id == 858 then item = true end end
assert(item and B.subtitle.text:find(ns.Me(), 1, true), "the bank's items, and who saw it")
