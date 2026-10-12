STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, GF, W, B, L = ns.Comm, ns.Gifts, ns.Wishlist, ns.Board, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
STUB.items[2589] = "|cffffffff|Hitem:2589::::::::20:::::::|h[Linen Cloth]|h|r"
STUB.items[765] = "|cffffffff|Hitem:765::::::::20:::::::|h[Silverleaf]|h|r"
STUB.items[2318] = "|cffffffff|Hitem:2318::::::::20:::::::|h[Light Leather]|h|r"

-- the wire: priced offers in their own kind
assert(C.Validate("sl", STUB.Rec{ p = "2589:15000,765:1" }) and C.Validate("sl", STUB.Rec{}), "sl format")
assert(not C.Validate("sl", STUB.Rec{ p = "2589:0" }) and not C.Validate("sl", STUB.Rec{ p = "2589" }) and not C.Validate("sl", STUB.Rec{ p = "1:1,2:1,3:1,4:1,5:1,6:1,7:1,8:1,9:1,10:1,11:1" }), "a price, at most ten")

-- prices typed in gold
assert(GF.ParsePrice("") == nil and GF.ParsePrice("0") == nil, "empty or 0: free")
assert(GF.ParsePrice("1,5") == 15000 and GF.ParsePrice("2") == 20000 and GF.ParsePrice("0.05") == 500, "gold with decimals")
assert(GF.ParsePrice("mucho") == false, "not a price")

-- offering: free goes in gv as before, priced in sl
assert(GF.Add(STUB.items[2589]), "free")
assert(GF.Add(STUB.items[765], 15000), "priced")
assert(tostring(last("gv").ids) == "2589", "free ones in gv: " .. tostring(last("gv").ids))
assert(last("sl").p == "765:15000", "priced ones in sl")
GF.Remove(765)
assert(last("sl").p == nil, "withdrawn")

-- a guildmate's offers: both kinds together, with the price
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421 }), "GUILD", "Mario-Testrealm")
W.Add(STUB.items[2318])
STUB.printed = {}
STUB.Receive("LVLM2", C.Encode("gv", STUB.Rec{ id = ns.NameKey("Mario"), ids = "765"}), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("sl", STUB.Rec{ id = ns.NameKey("Mario"), p = "2318:25000"}), "GUILD", "Mario-Testrealm")
local his = {}
for _, g in ipairs(GF.List()) do if g.name == "Mario" then his[g.id] = g end end
assert(his[765] and not his[765].price and his[2318] and his[2318].price == 25000, "free and priced")
local told
for _, line in ipairs(STUB.printed) do if line:find("Mario", 1, true) and line:find("[Light Leather]", 1, true) and line:find(GF.Money(25000), 1, true) then told = true end end
assert(told, "a wish on sale is told, with its price")
STUB.Receive("LVLM2", C.Encode("gv", STUB.Rec{ id = ns.NameKey("Mario") }), "GUILD", "Mario-Testrealm")
his = {}
for _, g in ipairs(GF.List()) do if g.name == "Mario" then his[g.id] = g end end
assert(not his[765] and his[2318], "his free list emptied; the priced one stays")

-- the tab: price in the kind column, "I'll buy it" in the menu
B.Toggle(); B.ShowTab("wishes")
local row
for _, r in ipairs(B.rows) do if r.button.wishId == 2318 and r.button.wishName == "Mario" then row = r end end
assert(row and row.group.text == GF.Money(25000), "the price shown: " .. tostring(row and row.group.text))
local made = {}
MenuUtil.CreateContextMenu = function(owner, fn) made = {}; local root = { CreateTitle = function() end, CreateButton = function(_, text, f) made[#made + 1] = { text = text, fn = f } end }; fn(owner, root) end
row.button.scripts.OnClick(row.button, "RightButton")
assert(made[1] and made[1].text == L.GIFT_BUY, "buy, not reserve")
made[1].fn()
STUB.Advance(12)
assert(last("gr").i == 2318 and last("gr").to == "Mario", "asks the seller")
assert(B.giftAdd.text == L.BTN_GIFT_ADD and L.BTN_GIFT_ADD ~= "", "the Offer button")

-- the dialog: a price box in offer mode
ns.Fire("LM_GIFT_ADD")
local D = ns.WishDialog
assert(D.price and D.price:IsShown(), "a price box")
D.box:SetText(STUB.items[2318]); D.price:SetText("3,5")
D.add.scripts.OnClick(D.add)
STUB.Advance(12)   -- the send allowance refills
assert(last("sl").p == "2318:35000", "offered at 3.5 gold: " .. tostring(last("sl").p))
D.box:SetText(STUB.items[765]); D.price:SetText("mucho")
D.add.scripts.OnClick(D.add)
assert(not GF.Has(765), "a bad price is refused")
ns.Fire("LM_WISH_ADD")
assert(not D.price:IsShown(), "no price for wishes")
