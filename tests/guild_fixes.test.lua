STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, A, B, I, AL, L = ns.Comm, ns.Ask, ns.Board, ns.Inactive, ns.Alts, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end

-- 2: a sender gets one question a minute here too
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("ask", { id = "q0000001", x = "uno" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("ask", { id = "q0000002", x = "dos" }), "GUILD", "Mario-Testrealm")
assert(#A.List() == 1, "the second within a minute is dropped")
STUB.Advance(61)
STUB.Receive("LVLM2", C.Encode("ask", { id = "q0000003", x = "tres" }), "GUILD", "Mario-Testrealm")
assert(#A.List() == 2, "a minute later it counts")

-- 1: hovering a question shows it whole, without an error
B.Toggle(); B.ShowTab("class")
local row
for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.classEntry and r.button.classEntry.kind == "ask" then row = r end end
row.button.scripts.OnEnter(row.button)
local hit
for _, line in ipairs(GameTooltip.lines) do if line == "tres" or line == "uno" then hit = true end end
assert(hit, "the question in the tooltip")

-- 3: a look before the guild roster has loaded does not start the "joined" dates
local members = {}
ns.db.joined = nil   -- as on a first login
C_Club.GetClubMembers = function() return members end
I.Scan()
assert(ns.db.joined == nil or ns.db.joined[GetGuildInfo("player")] == nil or ns.db.joined[GetGuildInfo("player")].since == nil, "no members yet: nothing noted")
members = { "Mario" }
C_Club.GetMemberInfo = function(_, id) return { name = id, level = 10, presence = 3, lastOnlineDay = 20 } end
I.Scan()
assert(I.List(14)[1].before, "the first real look marks those already there")

-- 4: an alt that is no longer in the guild is not sent
STUB.guildMembers = { Tester = true, Mario = true, Testalt = true }
C_Club.GetClubMembers = function() local out = {}; for k in pairs(STUB.guildMembers) do out[#out + 1] = k end; return out end
C_Club.GetMemberInfo = function(_, id) return { name = id, level = 1, presence = 1, role = 4 } end
ns.Roster.InvalidateGuildRoster()
ns.db.characters["Testalt-Testrealm"] = { name = "Testalt", realm = "Testrealm", level = 14, guild = "Test Guild", t = time() }
ns.db.characters["Gone-Testrealm"] = { name = "Gone", realm = "Testrealm", level = 9, guild = "Test Guild", t = time() }
AL.SetSharing()
assert(last("al").n == "Testalt", "only alts still in the guild: " .. tostring(last("al").n))
