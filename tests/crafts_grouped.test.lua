STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, P, R, L = ns.Comm, ns.Board, ns.Professions, ns.Roster, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
STUB.guildMembers = { Tester = true, Mario = true, Ana = true }
R.InvalidateGuildRoster()

-- the journal keeps the maximum rank too, and it travels
STUB.skills = { { skillID = 129, name = "First Aid", rank = 37, maxRank = 75 }, { skillID = 186, name = "Mining", rank = 6, maxRank = 75 }, { skillID = 185, name = "Cooking", rank = 7, maxRank = 75 } }
STUB.Fire("SKILL_LINES_CHANGED")
assert(ns.char.skills[129].max == 75, "max rank kept")
assert(C.Validate("pf", { p = "129:37:75,185:7" }) and C.Validate("pf", { p = "129:37:451" }) == false, "rank:max pairs")
assert(last("pf") and last("pf").p == "129:37:75,185:7:75,186:6:75", "shared with the max: " .. tostring(last("pf") and last("pf").p))

STUB.Receive("LVLM", C.Encode("hb", { l = 30, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("pf", { p = "129:75:75" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1421 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM", C.Encode("pf", { p = "186:40" }), "GUILD", "Ana-Testrealm")
R.mates.Ana = nil   -- Ana logged off

-- grouped by profession: a header with its icon, then who has it, highest first
B.ShowTab("crafts")
local rows = {}
for i = 1, #B.rows do if B.rows[i].button:IsShown() then rows[#rows + 1] = B.rows[i] end end
local shape = {}
for _, r in ipairs(rows) do shape[#shape + 1] = r.button.craftHeader and ("#" .. r.button.craftHeader) or (r.name.text:gsub("^%s+", "")) end
assert(table.concat(shape, ",") == "#185,Tester,#129,Mario,Tester,#186,Ana,Tester", "groups: " .. table.concat(shape, ","))
local head = rows[3]
assert(head.icon:IsShown() and head.icon.texture and head.name.text == P.Name(129) .. " (2)", "header: icon, name, count")
local mario, me1, ana = rows[4], rows[5], rows[7]
assert(mario.group.text == "75/75" and mario.xph.text == L.ONLINE and mario.barFill:IsShown() and mario.barFill:GetWidth() == B.BAR_W, "full bar, online")
assert(me1.group.text == "37/75" and me1.xph.text == "" and math.abs(me1.barFill:GetWidth() - B.BAR_W * 37 / 75) < 0.01, "my row: partial bar, no 'online'")
assert(ana.group.text == "40" and ana.xph.text ~= "" and ana.xph.text ~= L.ONLINE, "no max known: just the rank; offline: when seen")
-- right click a header: nothing; a guildmate: the menu
local opened = false
MenuUtil.CreateContextMenu = function() opened = true end
head.button.scripts.OnClick(head.button, "RightButton")
assert(not opened, "no menu on a header")
-- search keeps the header of what it finds
B.searchBox:SetText(P.Name(186):lower()); B.searchBox.scripts.OnTextChanged(B.searchBox)
local n = 0
for i = 1, #B.rows do if B.rows[i].button:IsShown() then n = n + 1 end end
assert(n == 3, "the Mining group only: " .. n)
B.searchBox:SetText(""); B.searchBox.scripts.OnTextChanged(B.searchBox)
-- bars only on this tab
B.ShowTab("mates")
for i = 1, #B.rows do assert(not B.rows[i].barFill:IsShown() and not B.rows[i].barBg:IsShown(), "no bars elsewhere") end
