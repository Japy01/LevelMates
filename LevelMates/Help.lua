-- Help.lua: "ask for a hand" requests and the waypoints they set. Sending anything to chat happens only from a click.
local _, ns = ...
local H = {}
ns.Help = H
local L, C, R = ns.L, ns.Comm, ns.Roster
H.active = {}
H.mine = nil
local EXPIRE = 600

local function newId() return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535)):sub(1, 8) end

local function myPosition()
	local mapId = C_Map.GetBestMapForUnit("player")
	if not mapId then return nil end
	local pos = C_Map.GetPlayerMapPosition(mapId, "player")
	if not pos then return mapId end
	local x, y = pos:GetXY()
	return mapId, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
end

-- `label`: set from a click (a guildmate's name, or a place): then the pin is also followed on screen and the chat says
-- where it points, or why it could not be set. Without it (an automatic pin) nothing is said or followed.
function H.WaypointTo(mapId, x, y, label)
	local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapId)
	local zone = info and info.name or tostring(mapId)
	if not (C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapId)) then
		if label then ns.Say(L.ROUTE_FAIL, zone) end
		return false
	end
	C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapId, x / 100, y / 100))
	if label then
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
		ns.Say(L.ROUTE_SET, label, zone, x, y)
	end
	return true
end

-- Called from a click (board button / slash command).
function H.Ask(text)
	text = strtrim(tostring(text or ""))
	text = text:gsub("[%c|]", "")
	text = ns.CutUtf8(text, 60)
	if text == "" then return false end
	if not IsInGuild() then ns.Say(L.HELP_NO_GUILD); return false end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	local mapId, x, y = myPosition()
	if not mapId or not x then ns.Say(L.HELP_NO_POS); return false end
	local id = newId()
	if C.Send("help", { t = text, z = mapId, x = x, y = y, id = id }, "now") then
		H.mine = { id = id, text = text, at = GetTime(), helpers = {} }
		ns.Say(L.HELP_SENT, text)   -- the asker sees it went out, not only the button's new text
		ns.Fire("LM_HELP_CHANGED")
		return true
	end
	ns.Say(L.HELP_NOT_SENT)   -- never fail in silence
	return false
end

function H.Cancel()
	if not H.mine then return end
	C.Send("helpok", { id = H.mine.id }, "now")
	H.mine = nil
	ns.Fire("LM_HELP_CHANGED")
end

function H.Expire()
	local now, gone = GetTime(), false
	for id, h in pairs(H.active) do if now - h.at > EXPIRE then H.active[id] = nil; gone = true end end
	if H.mine and now - H.mine.at > EXPIRE then H.mine = nil; gone = true end
	if gone then ns.Fire("LM_HELP_CHANGED") end   -- the check runs every minute: redraw only when something went
end

-- Active requests, oldest first (for the board).
function H.List()
	local out = {}
	for id, h in pairs(H.active) do out[#out + 1] = id end
	table.sort(out, function(a, b) return H.active[a].at < H.active[b].at end)
	return out
end

C.OnMessage("help", function(f, name)
	if not ns.db.settings.helpNotices then return end
	H.active[f.id] = { name = name, text = f.t, mapId = f.z, x = f.x, y = f.y, at = GetTime() }
	local info = C_Map.GetMapInfo and C_Map.GetMapInfo(f.z)
	ns.NoticeAt("home", L.HELP_NOTICE, name, f.t, info and info.name or tostring(f.z))
	if ns.db.settings.sound and PlaySound then PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) end
	if f.z == C_Map.GetBestMapForUnit("player") then H.WaypointTo(f.z, f.x, f.y) end
	ns.Fire("LM_HELP_CHANGED")
end)
-- Someone pressed "On my way" on my request: remember who, so grouping with them closes it.
C.OnMessage("helpgo", function(f, name)
	if H.mine and H.mine.id == f.id then H.mine.helpers[name] = true; ns.Fire("LM_HELP_CHANGED") end
end)
C.OnMessage("helpok", function(f, name)
	local h = H.active[f.id]
	if h and h.name == name then H.active[f.id] = nil; ns.Chat(L.HELP_DONE, name); ns.Fire("LM_HELP_CHANGED") end   -- only the asker clears it
end)

-- "On my way": whispers the asker (spec §7). Runs only from the board button's click handler.
function H.Coming(id)
	local h = H.active[id]
	if not h then return end
	ns.SendChat(string.format(L.HELP_COMING, ns.Me()), "WHISPER", nil, h.name)
	C.Send("helpgo", { id = id }, "now")   -- an addon message, not chat: tells the asker who is coming
	ns.Fire("LM_HELP_GIVEN", id, h.name)   -- guild points, once per request (and twice a day per asker)
end

-- Grouping with someone who said "On my way" ends my request for everyone.
local groupFrame = CreateFrame("Frame")
groupFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
groupFrame:SetScript("OnEvent", function()
	if not H.mine then return end
	for name in pairs(H.mine.helpers) do
		if UnitInParty(name) or UnitInRaid(name) then
			ns.Chat(L.HELP_GROUPED, name)
			H.Cancel()
			return
		end
	end
end)

ns.Slash("help", function(rest) if H.mine then H.Cancel() else H.Ask(rest) end end)
ns.Slash("ayuda", function(rest) if H.mine then H.Cancel() else H.Ask(rest) end end)
ns.Slash("cancel", H.Cancel); ns.Slash("cancelar", H.Cancel)
ns.On("LM_HELP_BUTTON", function()
	if H.mine then H.Cancel(); return end
	StaticPopupDialogs["LEVELMATES_HELP"] = StaticPopupDialogs["LEVELMATES_HELP"] or {
		text = L.HELP_PROMPT .. "\n\n" .. L.HELP_POS_WARNING, button1 = OKAY, button2 = CANCEL, hasEditBox = true, maxLetters = 60, timeout = 0, whileDead = true, hideOnEscape = true,
		-- Mainline dialogs carry the edit box as dialog.EditBox / dialog:GetEditBox() (GameDialog.xml); there is no `editBox`.
		OnAccept = function(self) local eb = self.GetEditBox and self:GetEditBox() or self.EditBox; H.Ask(eb and eb:GetText()) end,
		EditBoxOnEnterPressed = function(self) local dialog = self:GetParent(); H.Ask(self:GetText()); dialog:Hide() end,
	}
	StaticPopup_Show("LEVELMATES_HELP")
end)
ns.On("LM_WORLD", function(isInitial) if isInitial then C_Timer.NewTicker(60, H.Expire) end end)

-- The panic key: a help request at once with a fixed text, at most every 30 seconds.
H.PANIC_GAP = 30
local lastPanic = -math.huge
function H.Panic()
	if GetTime() - lastPanic < H.PANIC_GAP then ns.Say(L.PANIC_WAIT); return false end
	if H.mine then H.Cancel() end   -- one request at a time: the old one is withdrawn first
	if H.Ask(L.PANIC_TEXT) then lastPanic = GetTime(); return true end
	return false
end
function LevelMates_Panic() H.Panic() end
BINDING_NAME_LEVELMATES_PANIC = L.BINDING_PANIC
ns.Slash("panico", H.Panic); ns.Slash("panic", H.Panic)
