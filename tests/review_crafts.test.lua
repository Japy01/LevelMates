-- the Crafts view, review fixes
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L, RC, P = ns.Board, ns.Comm, ns.L, ns.Recipes, ns.Professions
STUB.items[2300] = "|cff1eff00|Hitem:2300::::::::20:::::::|h[Embossed Leather Vest]|h|r"
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.guildMembers.Mario = true; ns.Roster.InvalidateGuildRoster()
STUB.Receive("LVLM2", C.Encode("rcp", { p = 165, r = 138, m = 225, i = RC.Encode({ 2300 }) }), "GUILD", "Mario-Testrealm")
-- an enchanter: spells only
STUB.Receive("LVLM2", C.Encode("rcp", { p = 333, r = 60, m = 75, s = RC.Encode({ 7418, 7420 }) }), "GUILD", "Mario-Testrealm")
B.Toggle(); B.ShowTab("crafts")
local CV = ns.CraftsView

-- 1: the old column headers are not drawn over the panes
for i = 1, 5 do assert((B.headText[i].text or "") == "", "header " .. i .. " blank: " .. tostring(B.headText[i].text)) end

-- 3: spell recipes count
local ench
for _, it in ipairs(CV.profs.items) do if it:IsShown() and it.prof == 333 then ench = it end end
assert(ench and ench.recipes.text == "2", "enchanting: two recipes: " .. tostring(ench and ench.recipes.text))

-- 2: item icons not cropped after the crafters' class icons
CV.Select(165)
CV.rows[1].scripts.OnClick(CV.rows[1], "LeftButton")
local tc = CV.rows[1].icon.texcoord
assert(CV.mode == "recipes" and (not tc or (tc[1] == 0 and tc[2] == 1)), "the item's whole icon")
CV.back.scripts.OnClick(CV.back)

-- 7: a profession's click during a search shows that profession
CV.search:SetText("embossed"); CV.search.scripts.OnTextChanged(CV.search)
assert(CV.mode == "search", "searching")
CV.Select(165)
assert(CV.mode == "crafters" and (CV.search:GetText() or "") == "", "the click ends the search")

-- 4: an item's name that arrives later redraws the crafts tab
local dirty = false
local real = ns.Dirty
ns.Dirty = function(v) if v == "board" then dirty = true end; real(v) end
STUB.Fire("GET_ITEM_INFO_RECEIVED", 2300, true)
ns.Dirty = real
assert(dirty, "redraw on item info")

-- 5: a selected profession that is gone: back to the first
CV.prof = 999
CV.Refresh()
assert(CV.prof ~= 999 and CV.title.text ~= "", "falls back to a profession that is there")

-- 6: someone no longer in the guild is not a crafter
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", "Pepe-Testrealm")
STUB.Receive("LVLM2", C.Encode("rcp", { p = 165, r = 200, m = 225, i = RC.Encode({ 2300 }) }), "GUILD", "Pepe-Testrealm")
STUB.guildMembers.Pepe = nil; ns.Roster.InvalidateGuildRoster()
local names = {}
for _, c in ipairs(RC.Crafters()) do names[c.name] = true end
assert(names.Mario and not names.Pepe, "only guildmates")

-- the empty hint sits under the header, and a crafter never read says just that
P.AddSample("Mario", { { id = 171, rank = 44, max = 75 } })
CV.Select(171)
CV.rows[1].scripts.OnClick(CV.rows[1], "LeftButton")
assert(CV.right.hint:IsShown() and CV.right.hint.point and CV.right.hint.point[1] == "TOPLEFT" and CV.right.hint.point[3] <= -100, "the hint below the header and search")
local readWord = (L.CV_CRAFTER_SUB:match("· (%S+) %%s$")) or ""
assert(readWord == "" or not CV.sub.text:find(readWord .. " " .. L.CV_NOT_READ, 1, true), "not 'read not read yet': " .. CV.sub.text)
