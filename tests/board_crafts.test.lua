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
local CV = ns.CraftsView
assert(CV.frame:IsShown(), "the crafts view")
local function profRow(id) for _, it in ipairs(CV.profs.items) do if it:IsShown() and it.prof == id then return it end end end
assert(profRow(171) and profRow(164), "alchemy and blacksmithing on the left")
CV.Select(171)
assert(CV.rows[1].name.text == "Mario" and CV.rows[1].rank.text == "200" and CV.rows[1].read.text:find(L.ONLINE, 1, true), "alchemy: Mario first, online")
assert(CV.rows[2].name.text == "Tester", "then mine")
-- right click: whisper and invite a guildmate, nothing on mine
entries = nil
CV.rows[2].scripts.OnClick(CV.rows[2], "RightButton")
assert(entries == nil, "no menu on my own row")
CV.rows[1].scripts.OnClick(CV.rows[1], "RightButton")
local function opt(t) for _, e in ipairs(entries) do if e.text == t then return e end end end
assert(opt(L.MENU_WHISPER) and opt(L.MENU_INVITE), "whisper and invite")
opt(L.MENU_WHISPER).cb()
assert(STUB.lastTell == "Mario", "whispers")
-- offline: when last seen, whisper only
R.mates.Mario = nil; B.Refresh()
assert(not CV.rows[1].read.text:find(L.ONLINE, 1, true) and CV.rows[1].read.text ~= "", "last seen when offline")
CV.rows[1].scripts.OnClick(CV.rows[1], "RightButton")
assert(opt(L.MENU_WHISPER) and not opt(L.MENU_INVITE), "offline: no invite")
-- Discord: grouped by profession
local t = ns.DiscordCopy.Text("crafts")
assert(t:find(L.TAB_CRAFTS, 1, true) and t:find("**" .. P.Name(171) .. "**: Mario 200, Tester 120", 1, true), "Discord text: " .. t)
-- empty, slash
SlashCmdList["LEVELMATES"]("oficios")
assert(B.tab == "crafts", "/lm oficios")
