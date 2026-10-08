-- LM_CommTest: ¿llegan los mensajes de addon en WoW Forever? Instalar en dos personajes de la misma
-- hermandad (dos cuentas o dos personas). Cada uno ve en su chat lo que recibe del otro.
--   Automático: 8 s después de entrar al mundo, envía un mensaje por HERMANDAD y otro por un CANAL
--   OCULTO temporal, desde un temporizador (sin clic). Vuelve a enviar cada 60 s.
--   Manual: /lmtest envía los mismos mensajes desde un comando (cuenta como clic).
-- Cada mensaje recibido se imprime: "RECIBIDO <vía> de <quien>: <texto>".
local PREFIX = "LMTEST"
local CHANNEL = "LMTestOculto"
local f = CreateFrame("Frame")
local say = function(t) print("|cff00ff00LM CommTest|r: " .. t) end

local function Has(name, fn) say(name .. ": " .. (type(fn) == "function" and "existe" or "NO existe")) end

local function Restricted()
	local fn = C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
	if type(fn) ~= "function" then return "?" end
	local ok, r = pcall(fn)
	return ok and tostring(r) or "error"
end

local function Send(how)
	local me = UnitName("player")
	local text = how .. " t=" .. date("%H:%M:%S")
	say("restringido=" .. Restricted() .. "; enviando (" .. how .. ")...")
	local ok, r = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, "GUILD")
	say("  GUILD -> " .. (ok and tostring(r) or ("ERROR " .. tostring(r))))
	local id = GetChannelName(CHANNEL)
	if id and id > 0 then
		ok, r = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, "CHANNEL", id)
		say("  CHANNEL " .. id .. " -> " .. (ok and tostring(r) or ("ERROR " .. tostring(r))))
	else
		say("  CHANNEL: aún no unido al canal " .. CHANNEL)
	end
	if IsInGroup() then
		ok, r = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, "PARTY")
		say("  PARTY -> " .. (ok and tostring(r) or ("ERROR " .. tostring(r))))
	end
end

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, ...)
	if event == "CHAT_MSG_ADDON" then
		local prefix, text, channel, sender = ...
		if prefix == PREFIX then say("RECIBIDO " .. tostring(channel) .. " de " .. tostring(sender) .. ": " .. tostring(text)) end
		return
	end
	say("cliente " .. tostring(GetBuildInfo and select(1, GetBuildInfo())) .. "; comprobando API:")
	Has("C_ChatInfo.RegisterAddonMessagePrefix", C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix)
	Has("C_ChatInfo.SendAddonMessage", C_ChatInfo and C_ChatInfo.SendAddonMessage)
	Has("JoinTemporaryChannel", JoinTemporaryChannel)
	Has("C_ChatInfo.AreOutgoingAddonChatMessagesRestricted", C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)
	local ok, r = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
	say("registro de prefijo: " .. (ok and tostring(r) or ("ERROR " .. tostring(r))))
	if type(JoinTemporaryChannel) == "function" then
		ok, r = pcall(JoinTemporaryChannel, CHANNEL)
		say("unirse a canal oculto " .. CHANNEL .. ": " .. (ok and tostring(r) or ("ERROR " .. tostring(r))))
	end
	say("en 8 s envío sin clic; /lmtest envía con clic")
	C_Timer.After(8, function() Send("timer") end)
	C_Timer.NewTicker(60, function() Send("timer60") end)
end)

SLASH_LMTEST1 = "/lmtest"
SlashCmdList["LMTEST"] = function() Send("clic") end
