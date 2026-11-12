STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local W, C = ns.Wishlist, ns.Comm
assert(W.Add("item:123"))
local native = ns.char.wishes
assert(not W.IsExternal() and not W.SetSource("needroll") and W.Has(123))
STUB.loadedAddons = { NeedRoll = true }
NeedRollDB = { wishlist = { current = "Raid", lists = { { name = "Raid", items = { {itemID=456}, {itemID=789}, {itemID=456} } }, {name="Other",items={{itemID=999}}} } } }
local original = NeedRollDB.wishlist.lists[1].items
assert(W.SetSource("needroll") and W.IsExternal())
assert(W.Has(456) and not W.Has(123) and #W.List() == 2)
assert(ns.char.wishes == native and native[1].id == 123, "native list is preserved")
assert(not W.Add("item:111") and not W.Remove(456) and not W.SetPriority(456, 1), "external source is read-only")
ns.Fire("LM_MY_LOOT", "item:456")
assert(#original == 3 and W.Has(456), "loot never edits NeedRoll")
W.SourceTick()
local function lastWishes()
 for i=#STUB.sent,1,-1 do local kind,f=C.Decode(STUB.sent[i].msg); if kind=="wl" then return f end end
end
STUB.Advance(10)
assert(lastWishes().ids == "456,789")
NeedRollDB.wishlist.current = "Other"
STUB.Advance(10)
assert(W.Has(999) and not W.Has(456) and lastWishes().ids == "999", "live list selection updates sharing")
local items=NeedRollDB.wishlist.lists[2].items
for i=1,12 do items[i]={itemID=1000+i} end
W.SourceTick(); STUB.Advance(10)
local effective,total=W.NeedRollItems()
assert(#effective==10 and total==12 and not W.Has(1011))
assert(W.SourceStatus():find("10",1,true) and W.SourceStatus():find("12",1,true))
items[1]={itemID=-1}; W.SourceTick(); STUB.Advance(10)
assert(#W.List()==0 and lastWishes().ids==nil, "incompatible source withdraws; never falls back silently")
items[1]={itemID=1001}
STUB.loadedAddons.NeedRoll=false; W.SourceTick(); STUB.Advance(10)
assert(not W.Has(1001))
assert(W.SetSource("local") and W.Has(123) and ns.char.wishes==native)
assert(NeedRollDB.wishlist.lists[1].items==original and #original==3)
assert(not W.SetSource("invalid"))
STUB.loadedAddons.NeedRoll=true
SlashCmdList.LEVELMATES("wishsource needroll")
assert(W.IsExternal())
ns.Board.ShowTab("wishes")
assert(ns.Board.subtitle.text == ns.L.WISH_SOURCE_SUB)
assert(not ns.Board.wishAdd:IsEnabled(), "external source does not offer a second editor")
W.SetSource("local"); ns.Board.Refresh()
assert(ns.Board.wishAdd:IsEnabled())
