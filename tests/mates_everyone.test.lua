-- everyone online in the guild shows, with the addon or without: Guildmates lists those without it under their own
-- heading (level and zone from the roster, "without the addon"), Who is where counts their zones, the online pill
-- counts everyone; a click on one still offers the card, a whisper and an invite
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L, R, DB = ns.Board, ns.Comm, ns.L, ns.Roster, ns.Dashboard
-- the roster: Pepe and Rosa online without the addon, Luis offline; Mario online with it
STUB.guildMembers = { Tester = true, Mario = true, Pepe = true, Rosa = true, Luis = true }
local info = { Tester = { level = 20, presence = 1 }, Mario = { level = 24, presence = 1, zone = "Los Baldíos" },
	Pepe = { level = 33, presence = 1, zone = "Vallefresno", classID = 3 }, Rosa = { level = 12, presence = 1, zone = "Vallefresno", classID = 5 }, Luis = { level = 40, presence = 3 } }
C_Club.GetMemberInfo = function(_, id) local x = info[id]; return { name = id .. "-Testrealm", level = x.level, presence = x.presence, zone = x.zone, classID = x.classID, role = 4, guildRankOrder = 4 } end
R.InvalidateGuildRoster(); ns.Members.Invalidate()
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")

B.Toggle(); B.ShowTab("mates")
local rows, header = {}, nil
for _, r in ipairs(B.rows) do if r.button:IsShown() then rows[#rows + 1] = r; if r.button.tall and r.name.text:find(L.NO_ADDON_HEADER, 1, true) then header = r end end end
local names = {}
for _, r in ipairs(rows) do if not r.button.tall then names[#names + 1] = r.name.text end end
assert(header and header.name.text:find("(2)", 1, true), "a heading for those without the addon, with their count: " .. tostring(header and header.name.text))
assert(table.concat(names, ","):find("Mario", 1, true) and table.concat(names, ","):find("Pepe", 1, true) and table.concat(names, ","):find("Rosa", 1, true) and not table.concat(names, ","):find("Luis", 1, true), "online ones listed, offline not: " .. table.concat(names, ","))
local pepe
for _, r in ipairs(rows) do if r.name.text == "Pepe" then pepe = r end end
assert(tostring(pepe.level.text) == "33" and pepe.zone.text == "Vallefresno" and pepe.group.text == L.NO_ADDON and pepe.button.mate == "Pepe", "Pepe from the roster: " .. tostring(pepe.zone.text))
-- the search narrows them too
B.search = "ros"; B.Refresh()
names = {}
for _, r in ipairs(B.rows) do if r.button:IsShown() and not r.button.tall then names[#names + 1] = r.name.text end end
assert(#names == 1 and names[1] == "Rosa", "search: " .. table.concat(names, ","))
B.search = ""; B.Refresh()
-- the online pill counts everyone online (me, Mario, Pepe, Rosa)
assert(B.pills.online.text.text and B.pills.online.text.text:find("4", 1, true), "four online: " .. tostring(B.pills.online.text.text))
-- Home: Who is where lists Vallefresno (2) and Los Baldíos (1)
B.ShowTab("home")
local zones = {}
for _, it in ipairs(DB.where.items) do if it:IsShown() then zones[#zones + 1] = it.text.text end end
assert(#zones == 2 and zones[1]:find("Vallefresno", 1, true) and zones[1]:find("(2)", 1, true), "zones of everyone online: " .. table.concat(zones, " | "))
assert(not DB.where.hint:IsShown(), "not empty any more")
