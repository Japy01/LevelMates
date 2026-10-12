-- the Quests view on the Groups tab, its menu and filter; the post button; group quests in common in Together
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, C, L, QH = ns.Board, ns.Comm, ns.L, ns.Questhub
local entries
MenuUtil.CreateContextMenu = function(owner, fn)
	entries = {}
	local root = { CreateTitle = function() end, CreateButton = function(_, text, cb) entries[#entries + 1] = { text = text, cb = cb } end }
	fn(owner, root)
end
local function has(text) for _, e in ipairs(entries) do if e.text == text then return e end end end
STUB.quests = { 101, 202 }
STUB.questTags = { [202] = { tagID = 1, tagName = "Group" } }
STUB.Receive("LVLM2", C.Encode("hb", { l = 21, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("qh", STUB.Rec{ id = "101." .. ns.NameKey("Mario"), q = 101, t = "Quest 101", l = 20, z = "Mulgore", g = 0 }), "GUILD", "Mario-Testrealm")
B.Toggle(); B.ShowTab("lfg")
assert(B.questsButton:IsShown(), "a Quests button")
B.questsButton.scripts.OnClick(B.questsButton)
local row
for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.questEntry then row = r end end
assert(row and row.name.text:find("Quest 101", 1, true), "the post as a row")
row.button.scripts.OnClick(row.button, "LeftButton")
assert(has(L.QH_ME_TOO) and has(L.DP_WHISPER) and has(L.DP_INVITE), "menu: me too, whisper, invite")
has(L.QH_ME_TOO).cb()
assert(QH.IJoined(row.button.questEntry.id), "me too from the menu")
-- filter cycles
assert(B.questFilter == "all"); B.questFilterButton.scripts.OnClick(B.questFilterButton); assert(B.questFilter == "zone", "filter: zone")
B.questFilterButton.scripts.OnClick(B.questFilterButton); B.questFilterButton.scripts.OnClick(B.questFilterButton)
assert(B.questFilter == "group", "filter: group")
B.questFilterButton.scripts.OnClick(B.questFilterButton); assert(B.questFilter == "all", "and back")
-- the post button: a menu of my quests
B.questPostButton.scripts.OnClick(B.questPostButton)
assert(has("Quest 202"), "my quests to post")
has("Quest 202").cb()
assert(QH.MineFor(202), "posted from the menu")
-- group quests in common (Mario shares his quests and has 202)
ns.Roster.mates["Mario"].quests = { [202] = true }
local gq = ns.Together.GroupQuests()
assert(#gq == 1 and gq[1].q == 202 and gq[1].with[1] == "Mario", "a group quest we share")
B.togetherButton.scripts.OnClick(B.togetherButton)
local quest = false
for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.togetherEntry and r.button.togetherEntry.quest then quest = true end end
assert(quest, "in Together")
