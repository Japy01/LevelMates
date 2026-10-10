STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, A, B, L = ns.Comm, ns.Ask, ns.Board, ns.L
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
assert(ns.db.settings.askNotices == true, "on by default")
assert(C.Validate("ask", { id = "ab12cd34", x = "¿Qué talentos para tanquear?" }) and not C.Validate("ask", { id = "ab12cd34" }), "ask format")

-- asking
assert(A.Ask("¿Armas o Furia para subir?"), "asked")
local f = last("ask")
assert(f and f.x == "¿Armas o Furia para subir?" and f.id, "sent to the guild")
assert(not A.Ask("otra"), "one question a minute")
STUB.Advance(61)
assert(not A.Ask("   "), "not empty")
assert(#A.List() == 1 and A.List()[1].mine, "mine is listed too")

-- receiving: only from my class (as the roster knows it)
STUB.Receive("LVLM", C.Encode("hb", { l = 24, z = 1421, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("hb", { l = 22, z = 1421, c = "MAGE" }), "GUILD", "Ana-Testrealm")
STUB.printed = {}
STUB.Receive("LVLM", C.Encode("ask", { id = "q0000001", x = "¿Dónde aprendo Golpe heroico?" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM", C.Encode("ask", { id = "q0000002", x = "¿Oveja o nova?" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM", C.Encode("ask", { id = "q0000003", x = "hola" }), "GUILD", "Nadie-Testrealm")
assert(#A.List() == 2, "Mario's and mine")
local line = STUB.printed[#STUB.printed]
assert(line:find("Mario", 1, true) and line:find("Golpe heroico", 1, true) and line:find("|Haddon:LevelMates:ask:Mario|h", 1, true), "a notice with [Answer]: " .. tostring(line))
STUB.Receive("LVLM", C.Encode("ask", { id = "q0000001", x = "¿Dónde aprendo Golpe heroico?" }), "GUILD", "Mario-Testrealm")
assert(#A.List() == 2, "the same question once")
STUB.ClickLink("addon:LevelMates:ask:Mario")
assert(STUB.lastTell == "Mario", "[Answer] opens a whisper")

-- the option silences the notice, the list keeps them; 24 hours
ns.db.settings.askNotices = false
STUB.printed = {}
STUB.Advance(61)   -- one question a minute from each sender
STUB.Receive("LVLM", C.Encode("ask", { id = "q0000004", x = "¿Escudo?" }), "GUILD", "Mario-Testrealm")
assert(#STUB.printed == 0 and #A.List() == 3, "silent but listed")
ns.db.questions[GetGuildInfo("player")]["q0000004"].t = time() - 25 * 3600
assert(#A.List() == 2, "gone after a day")

-- the Class tab: a Questions section, a click answers; the Ask button opens a box
B.Toggle(); B.ShowTab("class")
local row
for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.classEntry and r.button.classEntry.kind == "ask" and not r.button.classEntry.q.mine then row = r end end
assert(row and row.name.text == "Mario" and row.zone.text:find("Golpe heroico", 1, true), "Mario's question on the tab")
local made = {}
MenuUtil.CreateContextMenu = function(owner, fn) made = {}; local root = { CreateTitle = function() end, CreateButton = function(_, text, fn2) made[#made + 1] = { text = text, fn = fn2 } end }; fn(owner, root) end
STUB.lastTell = nil
row.button.scripts.OnClick(row.button, "LeftButton")
made[1].fn()
assert(STUB.lastTell == "Mario", "answer from the tab")
assert(B.classAsk and B.classAsk:IsShown(), "the Ask button on the Class tab")
B.classAsk.scripts.OnClick(B.classAsk)
assert(STUB.lastPopup == "LEVELMATES_ASK", "a box to write it")
STUB.Advance(61)
STUB.lastDialog.EditBox:SetText("¿Mejor arma a 25?")
StaticPopupDialogs.LEVELMATES_ASK.OnAccept(STUB.lastDialog)
assert(last("ask").x == "¿Mejor arma a 25?", "asked from the box")
