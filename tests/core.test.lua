-- Core: SavedVariables defaults, per-character table, event bus, slash dispatch.
STUB.Fire("ADDON_LOADED", "LevelMates")
assert(type(LevelMatesDB) == "table", "db created")
assert(LevelMatesDB.settings.share == true, "default share on")
assert(LevelMatesDB.settings.sharePos == false, "position off by default")
assert(LevelMatesDB.settings.transport == "auto", "transport auto")
local _, ns = ...
assert(ns.db == LevelMatesDB, "ns.db bound")
assert(ns.char and ns.char == LevelMatesDB.chars["Tester-Testrealm"], "per-character table")
local got
ns.On("LM_TEST", function(a) got = a end)
ns.Fire("LM_TEST", 42)
assert(got == 42, "internal bus")
local ran
ns.Slash("ping", function(rest) ran = rest end)
SlashCmdList["LEVELMATES"]("ping hola")
assert(ran == "hola", "slash subcommand with rest")
assert(ns.L.BOARD_TITLE == "Forever Guild", "locale loaded")
STUB.locale = "esES"
