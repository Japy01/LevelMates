STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local I, B, L = ns.Inactive, ns.Board, ns.L
-- the guild roster: presence 1 online, 3 offline; last online is "how long ago"
local roster = {
	Tester = { level = 20, presence = 1, guildRank = "Officer" },
	Mario = { level = 24, presence = 3, guildRank = "Member", lastOnlineDay = 2 },
	Ana = { level = 12, presence = 3, guildRank = "Member", lastOnlineDay = 20 },
	Luis = { level = 33, presence = 3, guildRank = "Veteran", lastOnlineMonth = 2, lastOnlineDay = 3 },
	Old = { level = 5, presence = 3, guildRank = "Member", lastOnlineYear = 1 },
}
STUB.guildMembers = {}
for name in pairs(roster) do STUB.guildMembers[name] = true end
C_Club.GetMemberInfo = function(_, id) local r = roster[id]; return { name = id .. "-Testrealm", level = r.level, presence = r.presence, guildRank = r.guildRank, lastOnlineYear = r.lastOnlineYear, lastOnlineMonth = r.lastOnlineMonth, lastOnlineDay = r.lastOnlineDay } end

-- the first look: everyone there "since before" today
I.Scan()
local first = time()
local list = I.List(14)
local names = {}
for _, e in ipairs(list) do names[#names + 1] = e.name end
assert(table.concat(names, ",") == "Old,Luis,Ana", "inactive for 14 days or more, longest first: " .. table.concat(names, ","))
assert(list[3].days == 20 and list[2].days == 63 and list[1].days == 365, "days away")
assert(list[3].before and list[3].joined == first, "joined before the first look")
assert(#I.List(30) == 2, "30 days")
-- someone new is dated from when LevelMates first sees them
STUB.Advance(86400)
roster.Nuevo = { level = 3, presence = 3, guildRank = "Initiate", lastOnlineDay = 15 }
STUB.guildMembers.Nuevo = true
I.Scan()
local nuevo
for _, e in ipairs(I.List(14)) do if e.name == "Nuevo" then nuevo = e end end
assert(nuevo and not nuevo.before and nuevo.joined == time(), "a real join date")
assert(I.JoinedText(nuevo) == string.format(L.INACTIVE_SINCE, date("%d/%m/%y", nuevo.joined)) and I.JoinedText(list[3]) == string.format(L.INACTIVE_BEFORE, date("%d/%m/%y", first)), "join texts")

-- the Recruit tab: officers switch to the inactive list and pick 14 or 30 days
STUB.iAmOfficer = true
B.Toggle(); B.ShowTab("recruit")
assert(B.recruitViewButton:IsShown() and B.recruitViewButton.text == L.BTN_INACTIVE, "the switch")
B.recruitViewButton.scripts.OnClick(B.recruitViewButton)
assert(not B.recruitPanel:IsShown() and B.heading.text == L.HEAD_INACTIVE, "the list instead of the templates")
local rows = {}
for _, r in ipairs(B.rows) do if r.button:IsShown() then rows[#rows + 1] = r end end
assert(#rows == 4 and rows[1].name.text == "Old" and rows[1].zone.text == "Member", "rows with name and rank: " .. #rows)
assert(B.recruitDaysButton:IsShown() and B.recruitDaysButton.text == string.format(L.INACTIVE_DAYS, 14), "14 days")
B.recruitDaysButton.scripts.OnClick(B.recruitDaysButton); STUB.MenuEntry(string.format(L.INACTIVE_DAYS, 30)).cb()   -- a dropdown of 14/30/60/90 (2026-10-17)
rows = {}
for _, r in ipairs(B.rows) do if r.button:IsShown() then rows[#rows + 1] = r end end
assert(#rows == 2 and ns.char.inactiveDays == 30, "30 days")
local text = ns.DiscordCopy.Text("recruit")
assert(text:find("Old", 1, true) and text:find("Luis", 1, true), "copy for Discord: " .. text)
B.recruitViewButton.scripts.OnClick(B.recruitViewButton)
assert(B.recruitPanel:IsShown() and not B.recruitDaysButton:IsShown(), "back to the templates")
-- the member list is read once for many redraws
local reads = 0
local realMembers = C_Club.GetClubMembers
C_Club.GetClubMembers = function(...) reads = reads + 1; return realMembers(...) end
ns.Inactive.Invalidate()
for _ = 1, 10 do I.List(14) end
assert(reads == 1, "one read for ten lists: " .. reads)
STUB.Fire("GUILD_ROSTER_UPDATE")
I.List(14)
assert(reads == 2, "read again after a roster update")
