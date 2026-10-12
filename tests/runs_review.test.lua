-- project 2 final review fixes
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local M, C, DC, L, DP, B = ns.Meetups, ns.Comm, ns.Discord, ns.L, ns.DungeonPanel, ns.Board
local posted = {}
SendChatMessage = function(text, chatType) posted[#posted + 1] = text end
C_Discord = { IsEnabled = function() return true end, IsGuildChannelLinked = function() return true end, IsUserOAuthed = function() return true end }
for _, n in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", n .. "-Testrealm") end

-- 1: a join's line counts the joiner; a leave's frees the slot
STUB.Receive("LVLM2", C.Encode("qd", STUB.Rec{ id = "ana00001", d = 5, at = M.Now() + 60, r = "T", dc = 1 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("qm", STUB.Rec{ id = "ana00001", m = "T=Ana" }), "GUILD", "Ana-Testrealm")
M.Join("ana00001", "H")
local line = posted[#posted]
assert(not line:find(L.ROLE_H, line:find(L.DC_FREE:gsub("%%s", ""), 1, true) or 1, true), "1: the joiner's slot is not missing: " .. line)
STUB.Receive("LVLM2", C.Encode("qm", STUB.Rec{ id = "ana00001", m = "T=Ana,H=" .. ns.Me() }), "GUILD", "Ana-Testrealm")
M.Leave("ana00001")
line = posted[#posted]
assert(line:find(L.ROLE_H, 1, true), "1: the leaver's slot is free again: " .. line)

-- 2: a held cancel line can still be sent from the panel
M.Create(5, M.Now() + 90, "", "T", true)
local mine
for _, m in ipairs(M.List(5)) do if m.by == ns.Me() then mine = m end end
STUB.inInstance, STUB.inCombat = true, true
M.Cancel(mine.id)
STUB.inInstance, STUB.inCombat = false, false
DP.Open(5)
local held
for _, l in ipairs(DP.lines) do if l.entry and l.entry.kind == "held" then held = l end end
assert(held and held.buttons[1]:IsShown(), "2: a line with its Discord button")
local n = #posted
held.buttons[1].scripts.OnClick(held.buttons[1])
assert(#posted == n + 1 and not DC.Held(mine.id), "2: sent from the click")

-- 3: "make it a run": the dialog shows the time it will use, at least 15 minutes ahead, on a quarter hour
for _, minute in ipairs({ 0, 1, 11, 12, 14, 15, 44, 46, 59 }) do
	local offset, h, mm = B.SoonSlot({ year = 2026, month = 10, day = 12, hour = 23, min = minute, sec = 0 })
	local base = 23 * 60 + minute
	local at = offset * 1440 + h * 60 + mm
	assert(mm % 15 == 0 and at - base >= 15 and at - base < 30, "3: " .. minute .. " -> " .. offset .. " " .. h .. ":" .. mm)
end
ns.MeetDialog.OpenAt(5, 1, 8, 30)
assert(ns.MeetDialog.hourButton.text == "08 h" and ns.MeetDialog.minuteButton.text == ":30", "3: the dialog shows it")

-- 4: a line-up too long to publish tells the leader
M.Create(6, M.Now() + 60, "", "T", false)
local run
for _, m in ipairs(M.List(6)) do if m.by == ns.Me() then run = m end end
local long = string.rep("Á", 35)
for i = 1, 3 do STUB.guildMembers[long .. i] = true end
ns.Roster.InvalidateGuildRoster()
local before = #STUB.printed
for i = 1, 3 do M.AddMember(run.id, long .. i, "D") end
local told = false
for i = before + 1, #STUB.printed do if STUB.printed[i]:find(L.RUN_TOO_LONG, 1, true) then told = true end end
assert(told, "4: told the line-up is too long")

-- 5: Together keeps a chosen role
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421, c = "WARRIOR" }), "GUILD", "Luis-Testrealm")
STUB.Receive("LVLM2", C.Encode("rol", { r = "D" }), "GUILD", "Luis-Testrealm")
for _, s in ipairs(ns.Together.Suggest()) do
	for _, r in ipairs(s.rows) do assert(not (r.name == "Luis" and r.role ~= "D"), "5: Luis chose damage") end
end
-- 5b: four chose damage (three fit); the fourth, a warrior, is not made a guessed tank
for _, n in ipairs({ "Mario", "Ana", "Pepe" }) do
	STUB.guildMembers[n] = true
	STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1421, c = "WARRIOR" }), "GUILD", n .. "-Testrealm")
	STUB.Receive("LVLM2", C.Encode("rol", { r = "D" }), "GUILD", n .. "-Testrealm")
end
ns.Roster.InvalidateGuildRoster()
for _, s in ipairs(ns.Together.Suggest()) do
	for _, r in ipairs(s.rows) do
		local chosen = ({ Mario = true, Ana = true, Pepe = true, Luis = true })[r.name]
		assert(not (chosen and r.role ~= "D"), "5b: " .. r.name .. " chose damage, placed as " .. r.role)
	end
end
