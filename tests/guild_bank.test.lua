-- the guild bank: read by whoever opens it (viewable tabs, stacks summed, money), shared on close
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GB, C = ns.GuildBank, ns.Comm
STUB.bank = { money = 1234567, tabs = {
	{ name = "Consum~ibles,|", slots = { [1] = { id = 858, n = 5 }, [2] = { id = 858, n = 3 }, [7] = { id = 2589, n = 20 } } },
	{ name = "Oficiales", view = false, slots = { [1] = { id = 999, n = 1 } } },
} }
STUB.Fire("GUILDBANKFRAME_OPENED"); STUB.Advance(3)
local snap = GB.Snapshot()
assert(snap and snap.m == 1234567 and #snap.tabs == 1 and snap.tabs[1].items[858] == 8 and snap.tabs[1].items[2589] == 20, "one viewable tab, stacks summed, money")
assert(snap.by == ns.Me(), "seen by me")
-- round trip of the wire format, names cleaned
local back = GB.Decode(GB.Encode(snap.tabs))
assert(back and back[1].items[858] == 8 and not back[1].name:find("[~,|]"), "round trip, separators out of the names")
-- shared on close
local n = #STUB.sent
STUB.Fire("GUILDBANKFRAME_CLOSED"); STUB.Advance(5)
local sent = false
for i = n + 1, #STUB.sent do local k = C.Decode(STUB.sent[i].msg); if k == "gbk" or k == "bl" then sent = true end end
assert(sent, "shared on close")
-- rows for the view, filtered by the search
assert(#GB.Rows() == 2 and #GB.Rows("2589") == 1, "rows and search")
-- a snapshot from the future is refused
STUB.Receive("LVLM2", C.Encode("gbk", STUB.Rec{ id = "bank", t = GetServerTime() + 900, m = 1, p = "X~1:1" }), "GUILD", "Mario-Testrealm")
assert(GB.Snapshot().by == ns.Me(), "future refused")
-- sharing off: nothing
ns.db.settings.shareBank = false
n = #STUB.sent
STUB.Fire("GUILDBANKFRAME_OPENED"); STUB.Advance(3); STUB.Fire("GUILDBANKFRAME_CLOSED"); STUB.Advance(5)
for i = n + 1, #STUB.sent do local k = C.Decode(STUB.sent[i].msg); assert(k ~= "gbk" and k ~= "bl", "nothing with sharing off") end
