STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local sent = #STUB.sent
SlashCmdList["LEVELMATES"]("sim muro")
SlashCmdList["LEVELMATES"]("sim mercadillo")
SlashCmdList["LEVELMATES"]("sim quedada")
assert(#ns.Feed.List() >= 4, "wall samples")
assert(#ns.Gifts.List() == 3, "giveaway samples")
assert(#ns.Meetups.List() == 2, "meetup samples")
assert(#STUB.sent == sent, "nothing sent")
SlashCmdList["LEVELMATES"]("sim off")
assert(#ns.Feed.List() == 0 and #ns.Gifts.List() == 0 and #ns.Meetups.List() == 0, "sim off removes them")
