STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.char.groupsView = "catalog"   -- these checks are about the catalogue cards (the Groups section opens on Groups)
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, M, D, R, L = ns.Comm, ns.Board, ns.Meetups, ns.Dungeons, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function said(text) local n = 0; for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then n = n + 1 end end; return n end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()
for _, n in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", n .. "-Testrealm") end
local now = M.Now()
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
-- records on the wire: a meetup, a join (id = meetup.joiner), a removal (x); revs only grow
local rev = 0
local function V() rev = rev + 1; return GetServerTime() + rev end
local function QD(id, d, at, n) return C.Encode("qd", { id = id, d = d, at = at, n = n, v = V(), e = GetServerTime() + 86400 }) end
local function QJ(id, r, who) return C.Encode("qj", { id = id .. "." .. ns.NameKey(who), r = r, v = V(), e = GetServerTime() + 86400 }) end
local function X(t, id) return C.Encode("x", { t = t, id = id, v = V(), e = GetServerTime() + 86400 }) end
local function pick(text) for _, e in ipairs(entries) do if e.text == text then e.cb(); return true end end; return false end

assert(C.Validate("qd", { id = "m1", d = 5, at = now + 60, v = 1, e = 2 }) and C.Validate("qj", { id = "m1.Ana", r = "H", v = 1, e = 2 }), "formats")
assert(C.Validate("qj", { id = "m1", r = "X", v = 1, e = 2 }) == false and C.Validate("qd", { id = "m1", d = 5, v = 1, e = 2 }) == false, "limits")

-- creating
assert(not M.Create(5, now + 2, "") and not M.Create(5, now + 8 * 1440, ""), "not now, not past 7 days")
assert(M.Create(5, now + 60, "traed agua"), "created")
local f = last("qd")
assert(f.d == 5 and f.at == now + 60 and f.n == "traed agua", "shared")
assert(M.Create(2, now + 120, "") and not M.Create(4, now + 180, "") and said(L.MEET_FULL) == 1, "two per person")
local mine = M.List(5)[1]
local function minenow() return M.List(5)[1] end
assert(M.When(mine) == string.format("%s %02d:%02d", L["DAY_" .. date("*t", mine.at * 60).wday], date("*t", mine.at * 60).hour, date("*t", mine.at * 60).min), "day and time")

-- guildmates join mine; I am told
STUB.Receive("LVLM2", QJ(mine.id, "H", "Ana"), "GUILD", "Ana-Testrealm")
assert(minenow().joined.Ana == "H" and said(string.format(L.MEET_JOINED, "Ana", D.Name(5), M.When(mine), L.ROLE_H)) == 1, "Ana joins")
STUB.Receive("LVLM2", QJ(mine.id, "D", "Nadie"), "GUILD", "Nadie-Testrealm")
assert(not minenow().joined.Nadie, "strangers cannot")
STUB.Receive("LVLM2", X("qj", mine.id .. "." .. ns.NameKey("Ana")), "GUILD", "Ana-Testrealm")
assert(not minenow().joined.Ana, "Ana leaves")

-- a guildmate's meetup; I join it from the card
STUB.Receive("LVLM2", QD("mario01", 4, now + 30, "vamos"), "GUILD", "Mario-Testrealm")
assert(said(string.format(L.MEET_NEW, "Mario", D.Name(4), M.When({ at = now + 30 }))) == 1, "new meetup notice")
STUB.Receive("LVLM2", C.Encode("qd", { id = "mario01", d = 4, at = now + 30, v = V(), e = GetServerTime() + 86400 }), "GUILD", "Ana-Testrealm")
assert(M.List(4)[1].by == "Mario", "Ana cannot take Mario's meetup as hers")
B.ShowTab("lfg")
local card
for _, c in ipairs(B.cards) do if c:IsShown() and c.dungeonId == 4 then card = c end end
assert(card.badge:IsShown() and card.badge.text == M.When(M.List(4)[1]) .. " · 1/5", "the card shows the next run and its slots")
card.scripts.OnClick(card, "RightButton")
assert(pick(string.format(L.MEET_JOIN, M.When(M.List(4)[1]), L.ROLE_T)), "join as tank")
assert(last("qj").id == "mario01." .. ns.NameKey("Tester") and last("qj").r == "T" and M.MyRole("mario01") == "T", "qj sent, remembered")
card.scripts.OnEnter(card)
assert(table.concat(GameTooltip.lines, "\n"):find("Tester", 1, true), "the tooltip lists who joined")
card.scripts.OnClick(card, "RightButton")
assert(pick(string.format(L.MEET_LEAVE, M.When(M.List(4)[1]))) and last("x").t == "qj" and last("x").id == "mario01." .. ns.NameKey("Tester"), "leave")
assert(M.Join("mario01", "T"), "join again")

-- reminder: 15 minutes before, once, only if mine or joined
STUB.Receive("LVLM2", QD("ana00001", 6, now + 20), "GUILD", "Ana-Testrealm")
STUB.Advance(16 * 60)
M.Tick(); M.Tick()
assert(said(string.format(L.MEET_SOON, D.Name(4), M.When(M.List(4)[1]))) == 1, "reminded once for the joined one")
assert(said(string.format(L.MEET_SOON, D.Name(6), M.When(M.List(6)[1]))) == 0, "not for one I did not join")

-- cancel mine; the creator's cancel removes it everywhere
card = nil
for _, c in ipairs(B.cards) do if c:IsShown() and c.dungeonId == 5 then card = c end end
card.scripts.OnClick(card, "RightButton")
assert(pick(string.format(L.MEET_CANCEL, M.When(M.List(5)[1]))), "cancel in the menu")
StaticPopupDialogs.LEVELMATES_CONFIRM.OnAccept(STUB.lastDialog)   -- are you sure? yes
assert(last("x").t == "qd" and #M.List(5) == 0, "cancelled")
STUB.Receive("LVLM2", X("qd", "mario01"), "GUILD", "Ana-Testrealm")
assert(#M.List(4) == 1, "nobody else can cancel it")
STUB.Receive("LVLM2", X("qd", "mario01"), "GUILD", "Mario-Testrealm")
assert(#M.List(4) == 0 and not M.MyRole("mario01"), "Mario cancels it")

-- newcomers get my meetups and joins (after the 16 minutes above the guildmates re-announce themselves)
for _, nm in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", nm .. "-Testrealm") end
STUB.Receive("LVLM2", QD("luis0001", 3, now + 300), "GUILD", "Luis-Testrealm")
assert(M.Join("luis0001", "D"))
local n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("hi", { s = "" }), "GUILD", "Ana-Testrealm"); STUB.Advance(10)
local qd, qj = 0, 0
for i = n + 1, #STUB.sent do local k, ff = C.Decode(STUB.sent[i].msg); if k == "qd" then qd = qd + 1 elseif k == "qj" and ff.id == "luis0001." .. ns.NameKey("Tester") then qj = qj + 1 end end
assert(qd >= 1 and qj == 1, "handed over to the newcomer: the meetups I hold and my join")

-- gone 3 hours after the hour
STUB.Advance(8 * 3600)
assert(#M.List() == 0, "expired")

-- the dialog
ns.Fire("LM_MEET_HERE", 5)
local Dlg = ns.MeetDialog
assert(Dlg.frame:IsShown() and Dlg.dungeon == 5, "opens on the card's dungeon")
Dlg.dayOffset, Dlg.hour, Dlg.minute = 1, 21, 30
local t = date("*t")
local expect = math.floor((time() - (t.hour * 3600 + t.min * 60 + t.sec) + 86400 + 21 * 3600 + 30 * 60) / 60)
assert(Dlg.At() == expect, "tomorrow 21:30")
Dlg.ok.scripts.OnClick(Dlg.ok)
assert(last("qd").at == expect and not Dlg.frame:IsShown(), "created from the dialog")
