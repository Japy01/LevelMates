-- shared notes (mine; others' only from officers) and our own message of the day (officers only)
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local GN, C = ns.GuildNotes, ns.Comm
STUB.guildRoles = { Luis = 2 }; ns.Roster.InvalidateGuildRoster()
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end
assert(GN.SetNote(ns.Me(), "Tanque principal, horario de tarde"), "my note")
local f = last("gn")
assert(f and f.f == ns.Me() and f.id == ns.NameKey(ns.Me()) and GN.Note(ns.Me()) == "Tanque principal, horario de tarde", "stored and sent")
local function note(by, about, text) STUB.Receive("LVLM2", C.Encode("gn", STUB.Rec{ id = ns.NameKey(about), f = about, n = text }), "GUILD", by .. "-Testrealm") end
note("Mario", "Ana", "pirata")
assert(GN.Note("Ana") == nil, "not an officer: refused")
note("Luis", "Ana", "Sanadora")
local text, writer = GN.Note("Ana")
assert(text == "Sanadora" and writer == "Luis", "an officer may")
note("Ana", "Ana", "")
assert(GN.Note("Ana") == nil, "empty deletes (her own)")
-- the MOTD
local function motd(by, text) STUB.Receive("LVLM2", C.Encode("gmo", STUB.Rec{ id = "motd", n = text }), "GUILD", by .. "-Testrealm") end
motd("Mario", "hola")
assert(GN.Motd() == nil, "MOTD from a non-officer refused")
motd("Luis", "Mazmorra el sábado a las 21:00")
local m, by = GN.Motd()
assert(m == "Mazmorra el sábado a las 21:00" and by == "Luis", "MOTD from an officer")
-- relayed note of someone else by a non-officer owner: refused even when relayed
STUB.Receive("LVLM2", C.Encode("gn", STUB.Rec{ id = ns.NameKey("Pepe"), f = "Pepe", n = "falsa", o = "Mario" }), "GUILD", "Luis-Testrealm")
assert(GN.Note("Pepe") == nil, "a relayed forged note refused")
