STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, L = ns.Board, ns.L
B.Toggle()
assert(B.WIDTH == 680 and B.frame:GetWidth() == 680, "a wider window for nine tabs")
local found
for i, key in ipairs(B.GUILD_KEYS) do if key == "class" then found = i end end
assert(found and B.GUILD_KEYS[found - 1] == "crafts" and B.subs.class, "Class: a Guild sub-section, after Professions")
assert(L.TAB_CLASS and L.HEAD_CLASS and L.SUB_CLASS and L.SEARCH_CLASS, "its texts")
B.ShowTab("class")
assert(B.tab == "class" and B.heading.text == L.HEAD_CLASS, "it opens")

-- what it lists: builds of my class, the macro library and guildmates' macros, under headers
C_Spell = { GetSpellName = function(id) return "Spell" .. id end }
local macros = {}
function InCombatLockdown() return false end
function GetNumMacros() return 0, #macros end
function GetMacroIndexByName(n) for i, m in ipairs(macros) do if m.name == n then return 120 + i end end; return 0 end
function GetMacroInfo(i) local m = macros[i - 120]; if m then return m.name, 1, m.body end end
function CreateMacro(name, icon, body) macros[#macros + 1] = { name = name, body = body }; return #macros end
local C, R = ns.Comm, ns.Roster
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("tb", { c = "WARRIOR", s = 71, l = 24, p = "1001:15", b = "CODEmario" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("mc", { n = "Tank", x = "/cast Taunt\n/yell Here" }), "GUILD", "Mario-Testrealm")
B.Refresh()
local seen = {}
for _, r in ipairs(B.rows) do if r.button:IsShown() then seen[#seen + 1] = r end end
local function find(pred) for _, r in ipairs(seen) do if pred(r) then return r end end end
assert(find(function(r) return r.button.classEntry and r.button.classEntry.header == "builds" end), "a Builds header")
local mario = find(function(r) return r.button.classEntry and r.button.classEntry.kind == "build" end)
assert(mario and mario.name.text == "Mario" and mario.group.text == "24" and mario.xph.text == L.CLASS_VIEW, "Mario's build row")
local lib = find(function(r) return r.button.classEntry and r.button.classEntry.kind == "lib" end)
assert(lib and lib.xph.text == L.CLASS_CREATE and not lib.zone.text:find("\n", 1, true), "library rows, on one line")
local tank = find(function(r) return r.button.classEntry and r.button.classEntry.kind == "guild" end)
assert(tank and tank.name.text == "Tank" and tank.zone.text:find("Mario", 1, true), "a guildmate's macro")
tank.button.scripts.OnEnter(tank.button)
assert(GameTooltip.lines[2] == "/cast Taunt" and GameTooltip.lines[3] == "/yell Here", "the tooltip shows the whole macro")

-- menus: View build, Create macro, Whisper
local made = {}
MenuUtil.CreateContextMenu = function(owner, fn) made = {}; local root = { CreateTitle = function() end, CreateButton = function(_, text, f) made[#made + 1] = { text = text, fn = f } end }; fn(owner, root) end
local function pick(text) for _, m in ipairs(made) do if m.text == text then return m end end end
local ref
SetItemRef = function(link) ref = link end
mario.button.scripts.OnClick(mario.button, "LeftButton")
pick(L.CLASS_VIEW_BUILD).fn()
assert((STUB.printed[#STUB.printed] or ""):find("|Htalentbuild:71:24:CODEmario|h", 1, true), "View build")
assert(pick(string.format(L.LFG_WHISPER, "Mario")), "whisper")
tank.button.scripts.OnClick(tank.button, "LeftButton")
pick(L.CLASS_CREATE_MACRO).fn()
assert(macros[1] and macros[1].name == "Tank" and macros[1].body == "/cast Taunt\n/yell Here", "created from a guildmate's")
lib.button.scripts.OnClick(lib.button, "RightButton")
pick(L.CLASS_CREATE_MACRO).fn()
assert(#macros == 2, "created from the library")

-- Share macro: my macros, a click shares or withdraws
assert(B.classShare and B.classShare:IsShown(), "the share button on this tab")
B.classShare.scripts.OnClick(B.classShare)
local entry = pick(macros[1].name)
assert(entry, "my macros listed")
entry.fn()
assert(ns.Macros.IsShared("Tank"), "shared")
B.classShare.scripts.OnClick(B.classShare)
assert(pick(string.format(L.CLASS_SHARED_MARK, "Tank")), "marked as shared")
pick(string.format(L.CLASS_SHARED_MARK, "Tank")).fn()
assert(not ns.Macros.IsShared("Tank"), "withdrawn")
B.ShowTab("mates")
assert(not B.classShare:IsShown(), "only on the Class tab")
local text = ns.DiscordCopy.Text("class")
assert(text:find(L.TAB_CLASS, 1, true) and text:find("**Mario** (24)", 1, true), "copy for Discord: " .. text)

-- section headers span the row: never cut to the name column
B.ShowTab("class")
for _, r in ipairs(B.rows) do
	local c = r.button:IsShown() and r.button.classEntry
	if c and c.header then
		assert(r.name:GetWidth() >= 400 and r.name.text:find("(" .. c.count .. ")", 1, true), "a whole-row header: " .. tostring(r.name.text))
		if c.count == 0 then assert(r.name.text:find(L["CLASS_EMPTY_" .. c.header:upper()], 1, true), "the empty note beside it") end
		assert(r.zone.text == "", "nothing under it in the other columns")
	end
end
B.ShowTab("crafts"); B.ShowTab("class")
for _, r in ipairs(B.rows) do
	local c = r.button:IsShown() and r.button.classEntry
	if c and not c.header then assert(r.name:GetWidth() < 200, "entries keep the name column") end
end

-- icons: the class on builds and questions, the spell on macros, one per section
C_Spell.GetSpellTexture = function(x) return "icon:" .. tostring(x) end
STUB.atlases["classicon-warrior"] = true
B.Refresh()
for _, r in ipairs(B.rows) do
	local c = r.button:IsShown() and r.button.classEntry
	if c then
		assert(r.icon:IsShown(), "an icon on every row: " .. tostring(c.kind or c.header))
		if c.kind == "build" then assert(r.icon.atlas == "classicon-warrior", "class icon") end
		if c.kind == "lib" then assert(tostring(r.icon.texture):find("^icon:%d+"), "the macro's spell: " .. tostring(r.icon.texture)) end
		if c.kind == "guild" then assert(r.icon.texture == "icon:Taunt", "the shared macro's spell: " .. tostring(r.icon.texture)) end
	end
end
