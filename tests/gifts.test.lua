STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, W, GF, R, L = ns.Comm, ns.Board, ns.Wishlist, ns.Gifts, ns.Roster, ns.L
local function link(id, name) return "|cff1eff00|Hitem:" .. id .. "::::::::20:::::::|h[" .. (name or ("Item " .. id)) .. "]|h|r" end
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
local function said(text) for _, p in ipairs(STUB.printed) do if p:find(text, 1, true) then return true end end; return false end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true, Luis = true }
R.InvalidateGuildRoster()
for _, n in ipairs({ "Mario", "Ana", "Luis" }) do STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", n .. "-Testrealm") end
for id = 1, 12 do STUB.items[1000 + id] = link(1000 + id, "Thing " .. id) end

assert(C.Validate("gv", {}) and C.Validate("gv", { ids = "1001,1002" }) and C.Validate("gr", { i = 1001, to = "Ana" }) and C.Validate("gr", { i = 1001 }) == false, "formats")

-- my giveaways
assert(GF.Add(link(1001)) and GF.Has(1001) and tostring(last("gv").ids) == "1001", "added and shared")
assert(not GF.Add(link(1001)) and said(L.GIFT_DUP), "no duplicates")
for id = 1002, 1010 do assert(GF.Add(link(id))) end
assert(not GF.Add(link(1011)) and said(string.format(L.GIFT_FULL, GF.MAX)), "at most 10")
for id = 1003, 1010 do GF.Remove(id) end

-- matching both ways
assert(W.Add(link(1011)))
STUB.Receive("LVLM", C.Encode("gv", { ids = "1011,1012" }), "GUILD", "Ana-Testrealm")
assert(said(string.format(L.GIFT_FOR_YOU, "Ana", link(1011, "Thing 11"))), "Ana gives what I want")
STUB.Receive("LVLM", C.Encode("wl", { ids = "1002" }), "GUILD", "Mario-Testrealm")
assert(said(string.format(L.GIFT_WANTED, "Mario", link(1002, "Thing 2"))), "Mario wants what I give")
STUB.Receive("LVLM", C.Encode("gv", { ids = "1006" }), "GUILD", "Luis-Testrealm")
assert(W.Add(link(1006)) and said(string.format(L.GIFT_FOR_YOU, "Luis", link(1006, "Thing 6"))), "a new wish finds a giveaway")
assert(#GF.GivenBy(1011) == 1 and GF.GivenBy(1011)[1] == "Ana", "who gives it")

-- reserving: first come
assert(GF.Reserve("Ana", 1011)); STUB.Advance(12)   -- the burst of gv above used the send allowance
assert(last("gr").i == 1011 and last("gr").to == "Ana", "I reserve Ana's")
STUB.Receive("LVLM", C.Encode("gr", { i = 1002, to = "Tester" }), "GUILD", "Mario-Testrealm")
assert(GF.Has(1002).reservedBy == "Mario" and said(string.format(L.GIFT_RESERVED, "Mario", link(1002, "Thing 2"))), "Mario reserves mine")
STUB.Receive("LVLM", C.Encode("gr", { i = 1002, to = "Tester" }), "GUILD", "Luis-Testrealm")
assert(GF.Has(1002).reservedBy == "Mario", "first come")

-- tooltip
local lines = {}
GameTooltip.AddLine = function(self, t) lines[#lines + 1] = t end
STUB.TooltipPost(Enum.TooltipDataType.Item, GameTooltip, { id = 1011 })
local found = false
for _, l in ipairs(lines) do if l == string.format(L.GIFT_TOOLTIP, "Ana") then found = true end end
assert(found, "tooltip: who gives it")

-- the Wishes tab: wants and gives
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
B.ShowTab("wishes")
assert(B.giftAdd:IsShown() and B.wishAdd:IsShown(), "both buttons")
assert(B.headText[4].text == L.COL_KIND, "the gives/wants column")
local function rowFor(name, id, kind) for i = 1, #B.rows do local r = B.rows[i]; if r.button:IsShown() and r.name.text == name and r.button.wishId == id and r.group.text == kind then return r end end end
local mineGift, anaGift, myWish = rowFor("Tester", 1002, L.GIVES), rowFor("Ana", 1012, L.GIVES), rowFor("Tester", 1011, L.WANTS)
assert(mineGift and anaGift and myWish, "rows for both kinds")
assert(mineGift.zone.text:find(string.format(L.GIFT_RESERVED_BY, "Mario"), 1, true), "reserved shown")
anaGift.button.scripts.OnClick(anaGift.button, "RightButton")
assert(entries[1].text == L.GIFT_RESERVE, "reserve a guildmate's gift")
entries[1].cb()
assert(last("gr").i == 1012, "reserved from the menu")
mineGift.button.scripts.OnClick(mineGift.button, "RightButton")
assert(entries[#entries].text == L.GIFT_REMOVE, "remove my gift")
entries[#entries].cb()
assert(not GF.Has(1002), "removed")
myWish.button.scripts.OnClick(myWish.button, "RightButton")
assert(entries[1].text == L.WISH_REMOVE, "my wish: as before")

-- the dialog in gift mode
B.giftAdd.scripts.OnClick(B.giftAdd)
local D = ns.WishDialog
assert(D.frame:IsShown() and D.mode == "gift", "gift mode")
ChatFrameUtil.InsertLink(link(1005))
D.add.scripts.OnClick(D.add)
assert(GF.Has(1005) and not W.Has(1005), "added as a gift")
D.frame:Hide()
B.wishAdd.scripts.OnClick(B.wishAdd)
assert(D.mode == "wish", "back to wish mode")
