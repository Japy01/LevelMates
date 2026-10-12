STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, F, GF, M, J, R, L = ns.Comm, ns.Feed, ns.Gifts, ns.Meetups, ns.Journal, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function said(text) local n = 0; for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then n = n + 1 end end; return n end
local function link(id, name) return "|cff0070dd|Hitem:" .. id .. "::::::::20:::::::|h[" .. name .. "]|h|r" end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()
for _, n in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", n .. "-Testrealm") end

-- #1: what happens inside a dungeon reaches the wall after leaving it
STUB.inInstance = true
J.Add("dungeon", { name = "Ragefire Chasm", mates = { "Mario" } })
J.Add("item", { link = link(9001, "Blue Sword"), q = 3 })
STUB.inInstance = false
local n = #STUB.sent
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(5)   -- held inside, out on leaving
local dun, itm = false, false
for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "fe" and f.k == "dun" then dun = true elseif k == "fe" and f.k == "itm" then itm = true end end
assert(dun and itm, "sent after the dungeon")
n = #STUB.sent
ns.Fire("LM_HB_SENT")
local again = 0
for i = n + 1, #STUB.sent do if (C.Decode(STUB.sent[i].msg)) == "fe" then again = again + 1 end end
assert(again == 0, "and only once")

-- #2: a reservation counts when the giver confirms it; a second reserver sees the first one's
STUB.items[1011] = link(1011, "Thing")
STUB.Receive("LVLM2", C.Encode("gv", STUB.Rec{ ids = "1011" }), "GUILD", "Ana-Testrealm")
assert(GF.Reserve("Ana", 1011) and last("gr").i == 1011, "asked")
local row
for _, g in ipairs(GF.List()) do if g.name == "Ana" and g.id == 1011 then row = g end end
assert(row.reservedBy == nil, "not mine until Ana confirms")
STUB.Receive("LVLM2", C.Encode("gro", { i = 1011, by = "Luis" }), "GUILD", "Ana-Testrealm")
for _, g in ipairs(GF.List()) do if g.name == "Ana" and g.id == 1011 then row = g end end
assert(row.reservedBy == "Luis", "Ana says Luis was first")
STUB.Receive("LVLM2", C.Encode("gro", { i = 1011, by = "Mario" }), "GUILD", "Luis-Testrealm")
for _, g in ipairs(GF.List()) do if g.name == "Ana" and g.id == 1011 then row = g end end
assert(row.reservedBy == "Luis", "only the giver confirms")
-- the giver's side: confirms the first, re-sends to newcomers
assert(GF.Add(link(1012, "Mine")))
STUB.Receive("LVLM2", C.Encode("gr", { i = 1012, to = "Tester" }), "GUILD", "Mario-Testrealm")
assert(last("gro") and last("gro").i == 1012 and last("gro").by == "Mario", "I confirm Mario")
STUB.Receive("LVLM2", C.Encode("gr", { i = 1012, to = "Tester" }), "GUILD", "Luis-Testrealm")
assert(last("gro").by == "Mario", "Luis gets nothing")
n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Luis-Testrealm"); STUB.Advance(6)
local gro = false
for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "gro" and f.i == 1012 then gro = true end end
assert(gro, "re-sent to a newcomer")
for _, nm in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", nm .. "-Testrealm") end

-- #3: the reminder is remembered with the character (a /reload does not repeat it)
assert(M.Create(5, M.Now() + 30, ""))
local mine = M.List(5)[1]
STUB.Advance(16 * 60); M.Tick()
assert(said(string.format(L.MEET_SOON, ns.Dungeons.Name(5), M.When(mine))) == 1, "reminded")
assert(LevelMatesDB.chars[ns.PlayerKey()].meetReminded[mine.id] == true, "saved")
for _, nm in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", nm .. "-Testrealm") end

-- #4: a cancel inside a dungeon is kept and goes out after leaving (sync v2)
STUB.inInstance = true
assert(M.Cancel(mine.id) and #M.List(5) == 0 and ns.Sync.Store("qd")[mine.id].pending, "cancelled here, waiting to go out")
STUB.inInstance = false
STUB.Fire("ZONE_CHANGED_NEW_AREA"); STUB.Advance(5)
assert(not ns.Sync.Store("qd")[mine.id].pending, "out after leaving")

-- #5: the dialog's time is the local wall-clock time on that day (DST-safe through time(table))
local Dlg = ns.MeetDialog
ns.Fire("LM_MEET_HERE", 4)
Dlg.dayOffset, Dlg.hour, Dlg.minute = 3, 21, 15
local at = Dlg.At()
local t, want = date("*t", at * 60), date("*t", time() + 3 * 86400)
assert(t.year == want.year and t.month == want.month and t.day == want.day and t.hour == 21 and t.min == 15, "day + 3 at 21:15")
