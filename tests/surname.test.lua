-- Forever: a character called "Gigasamba Caramba". The game gives UnitName("player") as "Gigasamba", "Caramba"
-- (the surname where the realm would go); the guild sees the full name.
local realUnitName = UnitName
UnitName = function(u) if u == "player" then return "Gigasamba", "Caramba" end; return realUnitName(u) end
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
assert(ns.Me() == "Gigasamba Caramba", "my full name: " .. tostring(ns.Me()))
assert(ns.PlayerKey() == "Gigasamba Caramba-" .. GetRealmName(), "my key on my realm: " .. ns.PlayerKey())
-- my own card is mine: no whisper or invite to myself
ns.MateCard.Show("Gigasamba Caramba")
assert(not ns.MateCard.whisper:IsShown() and not ns.MateCard.invite:IsShown(), "my card")
-- my own message echoed back by the server is not a guildmate's
local C = ns.Comm
local before = ns.Roster.mates["Gigasamba Caramba"]
STUB.Receive("LVLM", C.Encode("hb", { l = 20, z = 1412, c = "MAGE" }), "GUILD", "Gigasamba Caramba-" .. GetRealmName())
assert(ns.Roster.mates["Gigasamba Caramba"] == before, "my echo ignored")
-- a plain name stays as it is
UnitName = function(u) if u == "player" then return "Mario", nil end; return realUnitName(u) end
assert(ns.Me() == "Mario", "no surname")
UnitName = function(u) if u == "player" then return "Mario", GetRealmName() end; return realUnitName(u) end
assert(ns.Me() == "Mario", "the realm is not a surname")
