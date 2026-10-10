STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, G, D, L = ns.Comm, ns.Board, ns.LFG, ns.Dungeons, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function said(text) for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then return true end end; return false end
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function pick(text) for _, e in ipairs(entries) do if e.text == text then e.cb(); return true end end; return false end
local function has(text) for _, e in ipairs(entries) do if e.text == text then return true end end; return false end
STUB.player.level = 15
for _, n in ipairs({ "Mario", "Ana", "Luis", "Eva", "Pepe" }) do STUB.Receive("LVLM", C.Encode("hb", { l = 16, z = 1421 }), "GUILD", n .. "-Testrealm") end

assert(C.Validate("lfj", { id = "ad1", r = "T" }) and C.Validate("lfj", { id = "ad1", r = "X" }) == false and C.Validate("lfjx", { id = "ad1" }), "formats")

-- I join Mario's ad from its card
STUB.Receive("LVLM", C.Encode("lfg", { d = 2, r = "T", id = "mario001", m = 20 }), "GUILD", "Mario-Testrealm")
B.ShowTab("lfg")
B.OpenDungeonMenu(2)
assert(has(string.format(L.LFJ_JOIN, "Mario", L.ROLE_H)), "join entries per role")
assert(pick(string.format(L.LFJ_JOIN, "Mario", L.ROLE_H)), "join as healer")
assert(last("lfj").id == "mario001" and last("lfj").r == "H" and G.myJoins.mario001 == "H", "lfj sent")
B.OpenDungeonMenu(2)
assert(not has(string.format(L.LFJ_JOIN, "Mario", L.ROLE_H)) and pick(string.format(L.LFJ_LEAVE, "Mario")), "then: leave")
assert(last("lfjx").id == "mario001" and not G.myJoins.mario001, "lfjx sent")

-- my own ad: others join, I get notices, the group fills, I can invite them
STUB.Advance(31)
assert(G.Post(5, "T"), "I post")
local id = G.mine.id
STUB.Receive("LVLM", C.Encode("lfj", { id = id, r = "H" }), "GUILD", "Ana-Testrealm")
assert(said(string.format(L.LFJ_NOTICE, "Ana", D.Name(5), L.ROLE_H)) and UIErrorsFrame.messages[#UIErrorsFrame.messages]:find("Ana", 1, true), "Ana joins: notice")
STUB.Receive("LVLM", C.Encode("lfj", { id = id, r = "D" }), "GUILD", "Nadie-Testrealm")
assert(not G.mine.joined.Nadie, "strangers cannot join")
for _, n in ipairs({ "Luis", "Eva" }) do STUB.Receive("LVLM", C.Encode("lfj", { id = id, r = "D" }), "GUILD", n .. "-Testrealm") end
assert(not said(string.format(L.LFJ_FULL, D.Name(5))), "4 of 5: not full yet")
STUB.Receive("LVLM", C.Encode("lfj", { id = id, r = "D" }), "GUILD", "Pepe-Testrealm")
STUB.Receive("LVLM", C.Encode("lfj", { id = id, r = "D" }), "GUILD", "Pepe-Testrealm")
local full = 0
for _, p in ipairs(STUB.printed) do if p:find(string.format(L.LFJ_FULL, D.Name(5)), 1, true) then full = full + 1 end end
assert(full == 1, "full: told once")
B.OpenDungeonMenu(5)
assert(has(string.format(L.LFJ_INVITE, "Ana", L.ROLE_H)) and has(L.LFG_CANCEL_MINE), "invite each, withdraw")
STUB.Receive("LVLM", C.Encode("lfjx", { id = id }), "GUILD", "Ana-Testrealm")
assert(not G.mine.joined.Ana, "Ana left")

-- joins show in the card tooltip, survive a re-send of the ad and vanish with it
STUB.Receive("LVLM", C.Encode("lfj", { id = "mario001", r = "D" }), "GUILD", "Luis-Testrealm")
local card
for _, c in ipairs(B.cards) do if c:IsShown() and c.dungeonId == 2 then card = c end end
card.scripts.OnEnter(card)
assert(table.concat(GameTooltip.lines, "\n"):find("Luis", 1, true), "tooltip shows who joined")
STUB.Receive("LVLM", C.Encode("lfg", { d = 2, r = "T", id = "mario001", m = 19 }), "GUILD", "Mario-Testrealm")
assert(G.ads.mario001.joined.Luis == "D", "a re-sent ad keeps its joins")
STUB.Receive("LVLM", C.Encode("lfgx", { id = "mario001" }), "GUILD", "Mario-Testrealm")
assert(not G.ads.mario001, "gone with the ad")

-- my joins go again to newcomers while the ad lives
STUB.Receive("LVLM", C.Encode("lfg", { d = 4, r = "T", id = "ana00001", m = 20 }), "GUILD", "Ana-Testrealm")
assert(G.Join("ana00001", "D"))
local n = #STUB.sent
STUB.Receive("LVLM", C.Encode("ping", {}), "GUILD", "Eva-Testrealm"); STUB.Advance(6)
local again = false
for i = n + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); if k == "lfj" and f.id == "ana00001" then again = true end end
assert(again, "re-sent to a newcomer")
