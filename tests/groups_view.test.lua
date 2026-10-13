-- the Groups section: the Groups view (Now, today and tomorrow, later, chat, and the form) and the Catalogue
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, M, L, C, A = ns.Board, ns.Meetups, ns.L, ns.Comm, ns.Activities
local made
MenuUtil.CreateContextMenu = function(owner, fn) made = {}; local root = { CreateTitle = function() end, CreateButton = function(_, text, f) made[#made + 1] = { text = text, fn = f } end }; fn(owner, root) end
local function pick(text) for _, m in ipairs(made or {}) do if m.text == text then return m end end end
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("lfg", { d = 5, lr = "T", id = "mario001", m = 20 }), "GUILD", "Mario-Testrealm")
local today = date("*t", time())
local minsLeft = (23 - today.hour) * 60 + (59 - today.min)
M.AddSample("Ana", 4, math.min(90, math.max(6, minsLeft - 1)), {})
M.AddSample("Luis", 6, 3 * 24 * 60, {})

B.Toggle(); B.ShowTab("lfg")
local GV = ns.GroupsView
assert(L.TAB_LFG == "Groups" or L.TAB_LFG == "Grupos", "the section is Groups: " .. tostring(L.TAB_LFG))
assert(GV.frame:IsShown(), "opens on the Groups view")
for _, c in ipairs(B.cards) do assert(not c:IsShown(), "no catalogue cards here") end
-- sections
assert(GV.now.cards[1]:IsShown() and GV.now.cards[1].group.by == "Mario", "Mario's Now group")
assert(GV.soon.cards[1]:IsShown() and GV.soon.cards[1].group.by == "Ana", "Ana's run today or tomorrow")
assert(GV.later.items[1]:IsShown() and GV.later.items[1].text.text:find(ns.Dungeons.Name(6), 1, true), "Luis's run later")
-- the form: a named raid of 20, Now, as healer
local f = GV.form
f.kinds.r.scripts.OnClick(f.kinds.r)
assert(f.sizeButton:IsShown() == false or f.sizeButton:IsShown(), "size row exists")
f.activityButton.scripts.OnClick(f.activityButton)
assert(pick(A.Name(101)) and pick(A.Name(190)), "the raids in the menu")
pick(A.Name(190)).fn()
assert(f.name:IsShown() and f.sizeButton:IsShown(), "a named raid: the name and the size")
assert(not f.publish:IsEnabled(), "no name yet: cannot publish")
f.name:SetText("Azuregos"); f.name.scripts.OnTextChanged(f.name)
f.sizeButton.scripts.OnClick(f.sizeButton); pick("20").fn()
f.when[1].scripts.OnClick(f.when[1])   -- Now
assert(not f.hourButton:IsShown(), "Now: no hour")
f.roles.H.scripts.OnClick(f.roles.H)
f.publish.scripts.OnClick(f.publish)
local sent = last("lfg")
assert(sent and sent.d == 190 and sent.t == "Azuregos" and sent.lr == "H" and ns.LFG.mine, "published Now")
-- Other: the role row hides, it goes as "any"
STUB.Advance(31)
f.roles.T.scripts.OnClick(f.roles.T)
f.kinds.o.scripts.OnClick(f.kinds.o)
assert(not f.roles.T:IsShown(), "no roles for other")
f.name:SetText("farmear seda"); f.name.scripts.OnTextChanged(f.name)
f.publish.scripts.OnClick(f.publish)
sent = last("lfg")
assert(sent.d == 300 and sent.lr == "A" and sent.t == "farmear seda", "other, as any")
-- a dungeon tomorrow at 21:30
f.kinds.d.scripts.OnClick(f.kinds.d)
f.activityButton.scripts.OnClick(f.activityButton); pick(ns.Dungeons.Name(5)).fn()
f.when[3].scripts.OnClick(f.when[3])   -- tomorrow
assert(f.hourButton:IsShown(), "a day: the hour")
f.hourButton.scripts.OnClick(f.hourButton); pick("21 h").fn()
f.minuteButton.scripts.OnClick(f.minuteButton); pick(":30").fn()
ns.MeetDialog.dayOffset, ns.MeetDialog.hour, ns.MeetDialog.minute = 1, 21, 30
assert(GV.At() == ns.MeetDialog.At(), "the same day and hour rule")
local before = #M.List(5)
f.roles.T.scripts.OnClick(f.roles.T)
f.publish.scripts.OnClick(f.publish)
assert(#M.List(5) == before + 1, "a run tomorrow")
-- the catalogue
B.catalogButton.scripts.OnClick(B.catalogButton)
assert(not GV.frame:IsShown() and B.cards[1]:IsShown(), "the catalogue cards")
B.catalogChips.r.scripts.OnClick(B.catalogChips.r)
assert(B.cards[1].activityId == 101 and B.cards[1]:IsShown(), "raids")
B.catalogChips.p.scripts.OnClick(B.catalogChips.p)
assert(B.cards[1].activityId == 201, "PvP")
B.catalogChips.d.scripts.OnClick(B.catalogChips.d)
-- Prefill from a panel: back to Groups, dungeon 5 chosen
GV.Prefill(5)
assert(GV.frame:IsShown() and f.kind == "d" and f.d == 5, "prefilled")
