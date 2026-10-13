-- one list of groups (Now first, mine included, then scheduled) and the card: slots up to 5, role counters above
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GR, W, C, L, A = ns.Groups, ns.Widgets, ns.Comm, ns.L, ns.Activities
local made
MenuUtil.CreateContextMenu = function(owner, fn) made = {}; local root = { CreateTitle = function() end, CreateButton = function(_, text, f) made[#made + 1] = { text = text, fn = f } end }; fn(owner, root) end
local function pick(text) for _, m in ipairs(made or {}) do if m.text == text then return m end end end
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421, c = "PRIEST" }), "GUILD", "Ana-Testrealm")
ns.LFG.Post{ d = 5, role = "T" }
STUB.Receive("LVLM2", C.Encode("lfg", { d = 190, x = 20, t = "Azuregos", lr = "H", id = "raid0001", m = 20 }), "GUILD", "Mario-Testrealm")
ns.Meetups.AddSample("Ana", 203, 60, {})
local list = GR.List()
assert(#list == 3 and list[1].src == "now" and list[2].src == "now" and list[3].src == "meet", "Now first, then scheduled")
local mine, raid, av
for _, g in ipairs(list) do if g.mine then mine = g elseif g.d == 190 then raid = g else av = g end end
assert(mine and mine.d == 5 and raid and raid.name == "Azuregos" and av and av.size == 40, "the three")

local parent = UIParent
local card = W.GroupCard(parent, true)
card:Set(mine)
assert(card.slots[1]:IsShown() and #card.slots == 5 and not card.counters:IsShown(), "a small group: slots")
card:Set(raid)
assert(card.counters:IsShown() and not card.slots[1]:IsShown(), "a raid: counters")
assert(card.counters.rows[1].text.text:find("0/3", 1, true) and card.counters.rows[2].text.text:find("1/5", 1, true) and card.counters.rows[3].text.text:find("0/12", 1, true), "T 0/3, H 1/5, D 0/12")
-- Join on the raid: the free roles; pick tank
card.buttons[1].scripts.OnClick(card.buttons[1])
assert(pick(L.ROLE_T) and pick(L.ROLE_H) and pick(L.ROLE_D), "free roles offered")
pick(L.ROLE_T).fn()
assert(ns.LFG.myJoins.raid0001 == "T", "joined the raid as tank")
-- Alterac: one counter, Join with no menu
card:Set(GR.List()[3])
assert(card.counters.rows[1]:IsShown() and card.counters.rows[1].text.text:find("1/40", 1, true) and not card.counters.rows[2]:IsShown(), "no roles: one counter 1/40")
made = nil
card.buttons[1].scripts.OnClick(card.buttons[1])
assert(made == nil and ns.Meetups.MyRole(av.id) == "A", "joined as any, no menu")
-- my Now card: Withdraw, two clicks
for _, g in ipairs(GR.List()) do if g.mine then card:Set(g) end end
assert(card.buttons[2].text == L.GR_WITHDRAW, "Withdraw on mine: " .. tostring(card.buttons[2].text))
card.buttons[2].scripts.OnClick(card.buttons[2])
assert(ns.LFG.mine, "first click asks")
card.buttons[2].scripts.OnClick(card.buttons[2])
assert(not ns.LFG.mine, "second withdraws")
-- the dashboard's cards are group cards
ns.Board.Toggle(); ns.Board.ShowTab("home")
assert(ns.Dashboard.groups and ns.Dashboard.groups.cards[1].counters, "Home uses group cards")
