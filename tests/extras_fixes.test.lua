STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, G, P, J, R, L = ns.Comm, ns.Board, ns.LFG, ns.Professions, ns.Journal, ns.Roster, ns.L
local function hb(name, level) STUB.Receive("LVLM2", C.Encode("hb", { l = level or 16, z = 1421 }), "GUILD", name .. "-Testrealm") end
local function sentKinds(from) local out = {}; for i = from + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); out[#out + 1] = { k = k, f = f } end; return out end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true, Eva = true, Pepe = true }
R.InvalidateGuildRoster()
STUB.player.level = 15
for _, n in ipairs({ "Mario", "Ana", "Luis", "Eva", "Pepe" }) do hb(n) end

-- #1a: a joiner who leaves the game is no longer joined (no ghost "full", no invite for them)
STUB.Advance(31)
assert(G.Post(5, "T"), "I post")
local id = G.mine.id
STUB.Receive("LVLM2", C.Encode("lfj", { id = id, r = "H" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("bye", {}), "GUILD", "Ana-Testrealm")
assert(not G.mine.joined.Ana, "bye clears the join")
STUB.Receive("LVLM2", C.Encode("lfj", { id = id, r = "D" }), "GUILD", "Luis-Testrealm")
STUB.Advance(130); R.Expire()
assert(not G.mine.joined.Luis, "roster expiry clears it too")
for _, n in ipairs({ "Mario", "Eva", "Pepe" }) do hb(n) end
-- #1b: my joins are saved with the character (a /reload keeps "Leave")
STUB.Receive("LVLM2", C.Encode("lfg", { d = 2, r = "T", id = "mario001", m = 20 }), "GUILD", "Mario-Testrealm")
assert(G.Join("mario001", "H") and LevelMatesDB.chars[ns.PlayerKey()].lfgJoins.mario001 == "H", "saved")

-- #2: when the poster re-sends the ad (for a newcomer), I re-send my join after it
local n = #STUB.sent
STUB.Receive("LVLM2", C.Encode("lfg", { d = 2, r = "T", id = "mario001", m = 19 }), "GUILD", "Mario-Testrealm")
local again = false
for _, m in ipairs(sentKinds(n)) do if m.k == "lfj" and m.f.id == "mario001" then again = true end end
assert(again, "join re-sent after the ad")

-- #3: days offline between two levels do not count in the pace
J.Add("level", { level = 10, from = 9, took = 3600 })
J.Add("level", { level = 11, from = 10, took = 3 * 86400 })
J.Add("level", { level = 12, from = 11, took = 1800 })
local p = J.Pace()
assert(p and p.avg == 2700 and p.fastest == 12, "the 3-day level is left out: " .. tostring(p and p.avg))

-- #4: professions: no message per skill point; a new profession goes out at once
n = #STUB.sent
ns.char.skills = { [171] = { name = "Alchemy", rank = 120 } }
ns.Fire("LM_SKILLS_CHANGED")
local count = 0
for _, m in ipairs(sentKinds(n)) do if m.k == "pf" then count = count + 1 end end
assert(count == 1, "a new profession: sent")
n = #STUB.sent
for r = 121, 130 do ns.char.skills[171].rank = r; ns.Fire("LM_SKILLS_CHANGED") end
ns.Fire("LM_HB_SENT")
count = 0
for _, m in ipairs(sentKinds(n)) do if m.k == "pf" then count = count + 1 end end
assert(count == 0, "ten skill points: nothing yet")
STUB.Advance(61); ns.Fire("LM_HB_SENT")
local lastP
for _, m in ipairs(sentKinds(n)) do if m.k == "pf" then count = count + 1; lastP = m.f.p end end
assert(count == 1 and lastP == "171:130", "one message a minute later with the new rank")

-- #5: named quality colours never reach the screen
ns.Notice("%s", "|cnIQ3:|Hitem:6666::::|h[Blue Sword]|h|r")
assert(UIErrorsFrame.messages[#UIErrorsFrame.messages] == "[Blue Sword]", "plain on screen: " .. UIErrorsFrame.messages[#UIErrorsFrame.messages])

-- #6: the help line uses the whole width where the partner box is hidden
B.ShowTab("mates")
local narrow = B.subtitle:GetWidth()
B.ShowTab("journal")
assert(B.subtitle:GetWidth() > narrow, "wider on the journal")
