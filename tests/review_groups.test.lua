-- unified groups, final review: the fixes
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local A, G, M, C, L, B = ns.Activities, ns.LFG, ns.Meetups, ns.Comm, ns.L, ns.Board
local made
MenuUtil.CreateContextMenu = function(owner, fn) made = {}; local root = { CreateTitle = function() end, CreateButton = function(_, text, f) made[#made + 1] = { text = text, fn = f } end }; fn(owner, root) end
local function hb(n) STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421, c = "MAGE" }), "GUILD", n .. "-Testrealm") end
for _, n in ipairs({ "Mario", "Ana", "Luis" }) do hb(n) end

-- C1: a dungeon is five, whatever its levels; the form has no size row for it
assert(A.SizeOf(14) == 5 and A.SizeOf(14, 33) == 5, "a dungeon: five")
B.Toggle(); B.ShowTab("lfg")
local f = ns.GroupsView.form
f.kinds.d.scripts.OnClick(f.kinds.d)
f.activityButton.scripts.OnClick(f.activityButton)
for _, m in ipairs(made) do if m.text == ns.Dungeons.Name(14) then m.fn() end end
assert(not f.sizeButton:IsShown(), "no size row for a dungeon")

-- C2: a late login can get every join of a raid
assert((ns.Sync.Spec("qj").relayMax or 0) >= 400, "joins handed over in full")

-- C3: a Now group places by when people joined (their own clock), the same on every client
STUB.Receive("LVLM2", C.Encode("lfg", { d = 5, lr = "T", id = "mario001", m = 20 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("lfj", { id = "mario001", r = "H", w = 200 }), "GUILD", "Luis-Testrealm")
STUB.Receive("LVLM2", C.Encode("lfj", { id = "mario001", r = "H", w = 100 }), "GUILD", "Ana-Testrealm")
local s = G.Slots(G.ads.mario001)
assert(s.H[1] == "Ana" and s.waiting[1] == "Luis", "the first to join gets the place, whatever arrived first here")

-- I1: right-click on a raid card: create a group there, not the old dungeon menu
ns.char.groupsView = "catalog"; ns.char.catalogKind = "r"; B.Refresh()
local raidCard
for _, c in ipairs(B.cards) do if c:IsShown() and c.activityId == 101 then raidCard = c end end
raidCard.scripts.OnClick(raidCard, "RightButton")
assert(ns.GroupsView.frame:IsShown() and ns.GroupsView.form.d == 101, "a raid's right-click: create a group there")
ns.char.catalogKind = "d"

-- I2: no raw keys for roles when an ad has no roles left to want
assert(G.RolesShort(nil) == "" and G.RolesText(nil) == "", "nothing, not ROLE_SHORT_n...")

-- I3: a name fits the wire (60 bytes) even in letters of two bytes; a refused post keeps the old ad
local name = A.CleanName(string.rep("Ж", 40))
assert(#name <= 60, "cut to 60 bytes: " .. #name)
STUB.Advance(31)
assert(G.Post{ d = 5, role = "T" }, "an ad")
local id = G.mine.id
STUB.Advance(31)
local realSend = C.Send
C.Send = function(kind, ...) if kind == "lfg" then return false end; return realSend(kind, ...) end
assert(not G.Post{ d = 300, role = "A", t = "otra cosa" }, "a post that could not go out")
C.Send = realSend
assert(G.mine and G.mine.id == id, "a refused post keeps the old ad")

-- M1: a run just started stays (the leader still has its card)
M.AddSample("Mario", 6, -10, {})
local started = false
for _, g in ipairs(ns.Groups.List()) do if g.by == "Mario" and g.src == "meet" then started = true end end
assert(started, "a run started ten minutes ago is still listed")

-- M2: the card and Copy for Discord name raids and free names
M.AddSample("Ana", 101, 60, {})
local lines = table.concat(ns.MateCard.Lines("Ana"), "\n")
assert(lines:find(A.Name(101), 1, true), "the mate card names the raid: " .. lines)

-- M3: "Other" offers 5, 10 and 40
f.kinds.o.scripts.OnClick(f.kinds.o)
f.sizeButton.scripts.OnClick(f.sizeButton)
local sizes = {}
for _, m in ipairs(made) do sizes[m.text] = true end
assert(sizes["5"] and sizes["10"] and sizes["40"], "sizes for other")
