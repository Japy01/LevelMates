-- A welcome the first time and "what's new" after an update (audit 2026-10-17): a small window a few seconds after
-- login, once per version; /lm novedades brings it back; its buttons open the book and the options
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.VERSION = "0.6.1"
local WN, L, B = ns.WhatsNew, ns.L, ns.Board
assert(ns.db.seenVersion == nil, "a fresh install")
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
assert(not (WN.frame and WN.frame:IsShown()), "not at once: the login screen settles first")
STUB.Advance(8)
assert(WN.frame and WN.frame:IsShown(), "the welcome shows")
assert(WN.body.text:find(L.WN_WELCOME:sub(1, 30), 1, true), "the welcome text: " .. tostring(WN.body.text))
assert(WN.frame.TitleText.text:find("0.6.1", 1, true), "the version in the title: " .. tostring(WN.frame.TitleText.text))
assert(ns.db.seenVersion == "0.6.1", "remembered")
WN.frame:Hide()
-- a reload: not again
STUB.Fire("PLAYER_ENTERING_WORLD", false, true); STUB.Advance(10)
assert(not WN.frame:IsShown(), "once per version")
-- an update: the news
ns.db.seenVersion = "0.6.0"
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(10)
assert(WN.frame:IsShown() and WN.body.text:find(L.WN_NEWS[1]:sub(1, 30), 1, true) and not WN.body.text:find(L.WN_WELCOME:sub(1, 30), 1, true), "the news, not the welcome: " .. tostring(WN.body.text))
assert(ns.db.seenVersion == "0.6.1", "remembered")
-- a development checkout never nags
WN.frame:Hide(); ns.VERSION = "dev"; ns.db.seenVersion = "0.6.0"
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(10)
assert(not WN.frame:IsShown() and ns.db.seenVersion == "0.6.0", "dev: nothing")
ns.VERSION = "0.6.1"
-- the command and the buttons
SlashCmdList["LEVELMATES"]("novedades")
assert(WN.frame:IsShown(), "/lm novedades")
WN.open.scripts.OnClick(WN.open)
assert(B.frame and B.frame:IsShown() and not WN.frame:IsShown(), "open the book, the window closes")
SlashCmdList["LEVELMATES"]("novedades"); SlashCmdList["LEVELMATES"]("novedades")
assert(not WN.frame:IsShown(), "toggles")
print("ok")
