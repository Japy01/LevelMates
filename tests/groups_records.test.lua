-- every group carries its activity, size and slots per role, Now (lfg) and scheduled (qd)
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local G, M, C, A, L = ns.LFG, ns.Meetups, ns.Comm, ns.Activities, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function hb(name) STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421, c = "MAGE" }), "GUILD", name .. "-Testrealm") end
for i = 1, 45 do hb("P" .. i) end
hb("Mario")

-- Now: a named raid of 10, me as healer
assert(G.Post{ d = 190, x = 10, t = "Jefe de mundo: Azuregos", role = "H" }, "posted")
local f = last("lfg")
assert(f.d == 190 and f.x == 10 and f.t == "Jefe de mundo: Azuregos" and f.lr == "H", "the fields go out")
local s = G.Slots(G.mine)
assert(s.H[1] == ns.Me() and G.mine.caps.T == 2 and G.mine.caps.H == 3 and G.mine.caps.D == 5, "me in H; caps 2/3/5")
STUB.Receive("LVLM2", C.Encode("lfj", { id = G.mine.id, r = "T" }), "GUILD", "Mario-Testrealm")
assert(G.Slots(G.mine).T[1] == "Mario", "Mario placed as tank")
-- an "any" join to a raid is refused; a role join to a no-role group is refused
STUB.Receive("LVLM2", C.Encode("lfg", { d = 290, x = 10, t = "Asalto a Tarren Mill", lr = "A", id = "wpvp0001", m = 20 }), "GUILD", "P1-Testrealm")
assert(G.ads.wpvp0001 and G.ads.wpvp0001.caps.A == 10, "world PvP of 10 received")
assert(not G.Join("wpvp0001", "T"), "no roles: T refused")
assert(G.Join("wpvp0001", "A"), "joined as any")
for i = 2, 11 do STUB.Receive("LVLM2", C.Encode("lfj", { id = "wpvp0001", r = "A" }), "GUILD", "P" .. i .. "-Testrealm") end
local ws = G.Slots(G.ads.wpvp0001)
assert(#ws.A == 10 and #ws.waiting == 2, "ten placed (leader included), the rest wait: " .. #ws.A .. "/" .. #ws.waiting)

-- free names are cleaned and cut on receive; unknown activities without a name are ignored
STUB.Receive("LVLM2", C.Encode("lfg", { d = 300, x = 5, t = "farmear " .. string.rep("seda", 12), lr = "A", id = "oth00001", m = 20 }), "GUILD", "P2-Testrealm")
assert(G.ads.oth00001 and #G.ads.oth00001.t <= 40, "cut to 40")
STUB.Receive("LVLM2", C.Encode("lfg", { d = 250, lr = "A", id = "unk00001", m = 20 }), "GUILD", "P3-Testrealm")
assert(not G.ads.unk00001, "an unknown activity without a name: ignored")

-- scheduled: Alterac, no roles; 40 places, the 41st waits
assert(M.Create{ d = 203, at = M.Now() + 60, role = "A" }, "Alterac created")
local mine
for _, m in ipairs(M.List()) do if m.by == ns.Me() then mine = m end end
assert(mine and mine.size == 40 and mine.caps.A == 40, "its size and caps")
for i = 1, 40 do
	local jid = mine.id .. "." .. ns.NameKey("P" .. i)
	STUB.Receive("LVLM2", C.Encode("qj", STUB.Rec{ id = jid, r = "A" }), "GUILD", "P" .. i .. "-Testrealm")
end
for _, m in ipairs(M.List()) do if m.by == ns.Me() then mine = m end end
local ms = M.Slots(mine)
assert(#ms.A == 40 and #ms.waiting == 1, "40 placed, one waits: " .. #ms.A .. "/" .. #ms.waiting)
assert(M.IsFull(mine) and M.Count(mine) == 40, "full")
-- Discord: the type first, what is missing per role
local line = ns.Discord.Line("new", { id = "x", d = 101, at = M.Now() + 90, by = ns.Me(), role = "D", caps = A.Caps(101), size = 40, n = string.rep("n", 40), joined = {} })
assert(line:find("^%[LevelMates%]") and line:find(L.KIND_r, 1, true) and line:find(A.Name(101), 1, true), "type and name: " .. line)
assert(#line <= 236, "at most 236 bytes: " .. #line)
local now = ns.Discord.Line("new", { id = "y", d = 5, by = ns.Me(), role = "T", caps = A.Caps(5), size = 5, joined = {} })
assert(now:find(L.WHEN_NOW, 1, true), "a Now group says so: " .. now)
-- old callers still work
assert(M.Create(5, M.Now() + 120, "nota", "T", false), "the old signature")
