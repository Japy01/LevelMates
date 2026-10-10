STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, F, B, L = ns.Comm, ns.Feed, ns.Board, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
assert(ns.db.settings.shareDeaths == true, "on by default")
assert(C.Validate("fe", { k = "dth", a = 23, b = "The Barrens", t = 1 }), "deaths travel on the wall")

-- my death goes to the wall: level and zone, nothing else
STUB.player.zone = "The Barrens"
STUB.Fire("PLAYER_DEAD"); STUB.Advance(1)
local f = last("fe")
assert(f and f.k == "dth" and f.a == 20 and f.b == "The Barrens", "sent: level and zone")
local mine = F.List()[1]
assert(mine.k == "dth" and F.Text(mine) == string.format(L.FEED_DTH, 20, "The Barrens"), "on my wall")
ns.db.settings.shareDeaths = false
local n = #STUB.sent
STUB.Fire("PLAYER_DEAD"); STUB.Advance(1)
for i = n + 1, #STUB.sent do assert(C.Decode(STUB.sent[i].msg) ~= "fe", "the option stops it") end
ns.db.settings.shareDeaths = true

-- guildmates' deaths, and the cemetery filter
STUB.Receive("LVLM", C.Encode("hb", { l = 24, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "dth", a = 24, b = "Duskwood", t = F.Now() }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("fe", { k = "lvl", a = 25, t = F.Now() }), "GUILD", "Mario-Testrealm")
assert(#F.List(nil, true) == 2 and #F.List() == 3, "only deaths: " .. #F.List(nil, true) .. "/" .. #F.List())
B.Toggle(); B.ShowTab("feed")
assert(B.feedCemetery and B.feedCemetery:IsShown(), "the Cemetery button on the wall")
B.feedCemetery.scripts.OnClick(B.feedCemetery)
local shown = 0
for _, r in ipairs(B.rows) do if r.button:IsShown() then shown = shown + 1 end end
assert(shown == 2 and B.subtitle.text == string.format(L.FEED_CEMETERY_SUB, 2), "deaths only, with the week's count: " .. tostring(B.subtitle.text))
B.feedCemetery.scripts.OnClick(B.feedCemetery)
shown = 0
for _, r in ipairs(B.rows) do if r.button:IsShown() then shown = shown + 1 end end
assert(shown == 3, "everything again")
B.ShowTab("mates")
assert(not B.feedCemetery:IsShown(), "only on the wall")
