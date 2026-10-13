STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, P, R, L = ns.Comm, ns.Board, ns.Professions, ns.Roster, ns.L
STUB.guildMembers = { Tester = true, Mario = true, Ana = true }
R.InvalidateGuildRoster()
ns.char.skills = { [171] = { name = "Alchemy", rank = 120 } }
STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1421, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("pf", { p = "171:200,164:80" }), "GUILD", "Mario-Testrealm")
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function visible() local out = {}; for i = 1, #B.rows do if B.rows[i].button:IsShown() then out[#out + 1] = B.rows[i] end end; return out end

B.ShowTab("crafts")
assert(B.subs.crafts and B.frame.selectedTab == 4 and B.subs.crafts.lit, "a Guild sub-section, lit")
assert(B.headText[1].text == L.COL_WHO and B.headText[3].text == L.COL_PROGRESS and B.headText[4].text == L.COL_RANK and B.headText[5].text == L.COL_SEEN, "headers")
local function scaled(cols, i) local sum = 0; for _, w in ipairs(cols) do sum = sum + w end; return math.floor(cols[i] * (B.LIST_W - (#cols - 1) * B.GAP) / sum) end
assert(B.rows[1].zone:GetWidth() == scaled(B.CCOLS, 3), "column widths, in proportion")
local function name(r) return (r.name.text:gsub("^%s+", "")) end
local rows = visible()
assert(#rows == 5 and rows[1].button.craftHeader == 171 and name(rows[2]) == "Mario" and rows[2].group.text == "200" and rows[2].xph.text == L.ONLINE, "alchemy: Mario first, online")
assert(name(rows[3]) == "Tester" and rows[4].button.craftHeader == 164 and name(rows[5]) == "Mario", "then mine; then blacksmithing")
-- search by profession or name
B.searchBox:SetText(P.Name(164):lower()); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(#visible() == 2 and visible()[1].button.craftHeader == 164, "by profession")
B.searchBox:SetText("tester"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(#visible() == 2 and name(visible()[2]) == "Tester", "by name, under its header")
B.searchBox:SetText(""); B.searchBox.scripts.OnTextChanged(B.searchBox)
-- right click: whisper and invite a guildmate, nothing on mine
rows = visible()
rows[3].button.scripts.OnClick(rows[3].button, "RightButton")
assert(entries == nil, "no menu on my own row")
rows[2].button.scripts.OnClick(rows[2].button, "RightButton")
local function opt(t) for _, e in ipairs(entries) do if e.text == t then return e end end end
assert(opt(L.RC_THEIR_RECIPES) and opt(L.MENU_WHISPER) and opt(L.MENU_INVITE), "their recipes, whisper and invite")
opt(L.MENU_WHISPER).cb()
assert(STUB.lastTell == "Mario", "whispers")
-- offline: when last seen, whisper only
R.mates.Mario = nil; B.Refresh()
rows = visible()
assert(rows[2].xph.text ~= L.ONLINE and rows[2].xph.text ~= "", "last seen when offline")
rows[2].button.scripts.OnClick(rows[2].button, "RightButton")
assert(opt(L.MENU_WHISPER) and not opt(L.MENU_INVITE), "offline: no invite")
-- Discord: grouped by profession
local t = ns.DiscordCopy.Text("crafts")
assert(t:find(L.TAB_CRAFTS, 1, true) and t:find("**" .. P.Name(171) .. "**: Mario 200, Tester 120", 1, true), "Discord text: " .. t)
-- empty, slash
SlashCmdList["LEVELMATES"]("oficios")
assert(B.tab == "crafts", "/lm oficios")
