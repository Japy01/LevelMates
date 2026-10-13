-- /lm discordtest: for two minutes, says in chat what an addon receives from each Discord message (who, and the text or
-- that it is protected); nothing is sent anywhere
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local n = #STUB.printed
STUB.Fire("CHAT_MSG_GUILD_DISCORD", "hola", "Pepe")
assert(#STUB.printed == n, "off: nothing")
SlashCmdList.LEVELMATES("discordtest")
local sent = #STUB.sent
STUB.Fire("CHAT_MSG_GUILD_DISCORD", "Pepe (Discord) se apunta como sanador", "LevelMates")
local last = STUB.printed[#STUB.printed]
assert(last:find("LevelMates", 1, true) and last:find("se apunta como sanador", 1, true), "readable text shown: " .. tostring(last))
STUB.Fire("CHAT_MSG_GUILD_DISCORD", "|Kx6|k", "Japy")
last = STUB.printed[#STUB.printed]
assert(last:find("Japy", 1, true) and last:find(ns.L.DT_PROTECTED, 1, true), "a protected text says so: " .. tostring(last))
assert(#STUB.sent == sent, "nothing sent")
STUB.Advance(121)
n = #STUB.printed
STUB.Fire("CHAT_MSG_GUILD_DISCORD", "otra", "Pepe")
assert(#STUB.printed == n, "off after two minutes")
