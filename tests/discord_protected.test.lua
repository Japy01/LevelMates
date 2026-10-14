-- Forever protects C_Discord's link checks (IsGuildChannelLinked, IsUserOAuthed): an addon's call is blocked and the
-- game shows "LevelMates has been blocked from an action" (taint log 2026-10-14). They are never called; only
-- IsEnabled is asked, and the link is taken as unknown.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local DC, B = ns.Discord, ns.Board
local called = {}
C_Discord = { IsEnabled = function() return true end,
	IsGuildChannelLinked = function() called[#called + 1] = "linked" end, IsUserOAuthed = function() called[#called + 1] = "oauth" end,
	GetGuildLinkStatus = function() called[#called + 1] = "status" end }
local ok, why = DC.Available()
assert(ok and why == "DISCORD_UNSURE", "enabled: allowed, link unknown: " .. tostring(why))
B.Toggle(); B.Refresh(); B.ShowTab("lfg"); B.Refresh()
assert(#called == 0, "the protected checks are never called: " .. table.concat(called, ","))
C_Discord.IsEnabled = function() return false end
assert(select(2, DC.Available()) == "DISCORD_NO_GUILD", "not enabled")
