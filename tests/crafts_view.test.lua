-- the Crafts tab as two panes: professions on the left (who, how many recipes); the chosen one on the right with its
-- crafters (rank bar, when read); a crafter's recipes, Back; a search shows who crafts what; ask from a click
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L, RC, P = ns.Board, ns.Comm, ns.L, ns.Recipes, ns.Professions
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
STUB.items[2300] = "|cff1eff00|Hitem:2300::::::::20:::::::|h[Embossed Leather Vest]|h|r"
STUB.items[2304] = "|cffffffff|Hitem:2304::::::::20:::::::|h[Light Armor Kit]|h|r"
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412, c = "PRIEST" }), "GUILD", "Ana-Testrealm")
P.AddSample("Mario", { { id = 165, rank = 138, max = 225 } })
P.AddSample("Ana", { { id = 165, rank = 85, max = 150 }, { id = 185, rank = 20, max = 75 } })
STUB.Receive("LVLM2", C.Encode("rcp", { p = 165, r = 138, m = 225, i = RC.Encode({ 2300, 2304 }) }), "GUILD", "Mario-Testrealm")

B.Toggle(); B.ShowTab("crafts")
local CV = ns.CraftsView
assert(CV.frame:IsShown(), "the two panes")
for _, r in ipairs(B.rows) do assert(not r.button:IsShown(), "no list rows") end
local lw
for _, it in ipairs(CV.profs.items) do if it:IsShown() and it.prof == 165 then lw = it end end
assert(lw and lw.who.text == "2" and lw.recipes.text == "2", "Leatherworking: 2 crafters, 2 recipes")
assert(CV.footer.text:find("2", 1, true), "the footer counts: " .. tostring(CV.footer.text))
-- a profession: its crafters, highest first
lw.scripts.OnClick(lw)
assert(CV.title.text == P.Name(165) and CV.sub.text:find("2", 1, true), "its header")
local first = CV.rows[1]
assert(first:IsShown() and first.name.text == "Mario" and first.rank.text == "138", "Mario first, 138")
assert(CV.rows[2].name.text == "Ana", "then Ana")
-- a crafter: their recipes, Back
first.scripts.OnClick(first)
assert(CV.mode == "recipes" and CV.back:IsShown() and CV.title.text == "Mario", "Mario's recipes")
local names = {}
for _, r in ipairs(CV.rows) do if r:IsShown() then names[#names + 1] = r.name.text end end
assert(table.concat(names, ","):find("Embossed Leather Vest", 1, true) and table.concat(names, ","):find("Light Armor Kit", 1, true), "both recipes: " .. table.concat(names, ","))
-- a recipe: ask Mario for it (a whisper, from the click)
CV.rows[1].scripts.OnClick(CV.rows[1])
local ask
for _, e in ipairs(entries) do if e.text:find("Mario", 1, true) then ask = e end end
assert(ask, "ask Mario")
ask.cb()
assert(STUB.lastChat and STUB.lastChat.chatType == "WHISPER" and STUB.lastChat.target == "Mario", "the whisper went from the click")
CV.back.scripts.OnClick(CV.back)
assert(CV.mode == "crafters" and CV.rows[1].name.text == "Mario", "back to the crafters")
-- a search: who crafts it
CV.search:SetText("light armor"); CV.search.scripts.OnTextChanged(CV.search)
assert(CV.mode == "search" and CV.rows[1].name.text:find("Light Armor Kit", 1, true) and CV.rows[1].who.text:find("Mario", 1, true), "found, with who crafts it")
CV.search:SetText(""); CV.search.scripts.OnTextChanged(CV.search)
assert(CV.mode == "crafters", "an empty search: back to the profession")

-- online and the trainer hint on a crafter's row; right-click: whisper and invite (not on mine)
P.AddSample("Mario", { { id = 165, rank = 150, max = 150 } })
CV.Select(165)
local mario = CV.rows[1]
assert(mario.name.text == "Mario" and mario.read.text:find(L.ONLINE, 1, true) and mario.read.text:find(L.TRAIN_EXPERT, 1, true), "online, time to train: " .. tostring(mario.read.text))
entries = nil
mario.scripts.OnClick(mario, "RightButton")
local w, inv
for _, e in ipairs(entries or {}) do if e.text == L.MENU_WHISPER then w = e end; if e.text == L.MENU_INVITE then inv = e end end
assert(w and inv, "whisper and invite")
