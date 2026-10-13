-- who crafts it, from the Crafts tab's search; ask with a whisper (once a minute); their recipes
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L, RC = ns.Board, ns.Comm, ns.L, ns.Recipes
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function find(text) for _, e in ipairs(entries) do if e.text:find(text, 1, true) then return e end end end
STUB.items[858] = "|cffffffff|Hitem:858::::::::20:::::::|h[Lesser Healing Potion]|h|r"
STUB.items[929] = "|cffffffff|Hitem:929::::::::20:::::::|h[Healing Potion]|h|r"
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("rcp", { p = 171, r = 120, m = 150, i = RC.Encode({ 858, 929 }) }), "GUILD", "Mario-Testrealm")
assert(#RC.Find("lesser healing") == 1 and RC.Find("lesser healing")[1] == 858, "by name")
assert(RC.Find("858")[1] == 858 and RC.Find(STUB.items[858])[1] == 858, "by number and by link")
assert(#RC.Find("healing") == 2, "a part of the name")
B.Toggle(); B.ShowTab("crafts")
local CV = ns.CraftsView
CV.search:SetText("lesser healing"); CV.search.scripts.OnTextChanged(CV.search)
local row = CV.rows[1]
assert(row:IsShown() and row.name.text:find("Lesser Healing Potion", 1, true) and row.who.text:find("Mario", 1, true), "the item and Mario")
row.scripts.OnClick(row, "LeftButton")
local ask = find(string.format(L.RC_ASK_MENU, "Mario"))
assert(ask, "menu: ask Mario")
STUB.lastChat = nil
ask.cb()
assert(STUB.lastChat and STUB.lastChat.chatType == "WHISPER" and STUB.lastChat.target == "Mario" and STUB.lastChat.msg:find("item:858", 1, true), "a whisper with the link")
STUB.lastChat = nil
ask.cb()
assert(STUB.lastChat == nil, "not again within a minute")
-- his recipes: the profession, then Mario
CV.search:SetText(""); CV.search.scripts.OnTextChanged(CV.search)
CV.Select(171)
CV.rows[1].scripts.OnClick(CV.rows[1], "LeftButton")
local recipes = 0
for _, r in ipairs(CV.rows) do if r:IsShown() then recipes = recipes + 1 end end
assert(recipes == 2 and CV.mode == "recipes", "his recipes")
