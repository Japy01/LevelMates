STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local H, L = ns.Help, ns.L
UiMapPoint = { CreateFromCoordinates = function() return {} end }
-- sent: the asker is told so, not only by the button's text
STUB.printed = {}
assert(H.Ask("Ogro en la cueva"), "sent")
local said
for _, line in ipairs(STUB.printed) do if line:find(string.format(L.HELP_SENT, "Ogro en la cueva"), 1, true) then said = true end end
assert(said, "a confirmation that it went out")
H.Cancel()
-- not in a guild: say why, never fail in silence
STUB.player.guild = nil
STUB.printed = {}
assert(not H.Ask("Ogro"), "cannot send")
assert(STUB.printed[#STUB.printed] and STUB.printed[#STUB.printed]:find(L.HELP_NO_GUILD, 1, true), "says why: " .. tostring(STUB.printed[#STUB.printed]))
STUB.player.guild = "Test Guild"
-- any other refusal says so too
STUB.inInstance = true
STUB.printed = {}
local realPos = C_Map.GetBestMapForUnit
H.Ask("Ogro")
assert(#STUB.printed > 0, "a refusal is never silent")
STUB.inInstance = false
