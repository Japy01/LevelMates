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

function H.WaypointTo(mapId, x, y)
	if not (C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapId)) then return false end
	C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapId, x / 100, y / 100))
	return true
end

-- At most max bytes, never cutting a multi-byte UTF-8 character in half (continuation bytes are 0x80-0xBF).
local function cutUtf8(s, max)
	if #s <= max then return s end
	local at = max
	while at > 0 do
		local b = s:byte(at + 1)
		if b and b >= 128 and b <= 191 then at = at - 1 else break end
	end
	return s:sub(1, at)
end

-- Called from a click (board button / slash command).
function H.Ask(text)
	text = strtrim(tostring(text or ""))
	text = text:gsub("[%c|]", "")
	text = cutUtf8(text, 60)
	if text == "" then return false end
	if not C.IsReady() then ns.Say(L.HELP_NEEDS_SHARE); return false end
	local mapId, x, y = myPosition()
	if not mapId or not x then ns.Say(L.HELP_NO_POS); return false end
	local id = newId()
	if C.Send("help", { t = text, z = mapId, x = x, y = y, id = id }, "now") then
		H.mine = { id = id, text = text, at = GetTime() }
		ns.Fire("LM_HELP_CHANGED")
		return true
	end
	return false
end

function H.Cancel()
	if not H.mine then return end
	C.Send("helpok", { id = H.mine.id }, "now")
	H.mine = nil
	ns.Fire("LM_HELP_CHANGED")
end

function H.Expire()
	local now = GetTime()
	for id, h in pairs(H.active) do if now - h.at > EXPIRE then H.active[id] = nil end end
	if H.mine and now - H.mine.at > EXPIRE then H.mine = nil end
	ns.Fire("LM_HELP_CHANGED")
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
	ns.Say(L.HELP_NOTICE, name, f.t, info and info.name or tostring(f.z))
	if ns.db.settings.sound and PlaySound then PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) end
	if f.z == C_Map.GetBestMapForUnit("player") then H.WaypointTo(f.z, f.x, f.y) end
	ns.Fire("LM_HELP_CHANGED")
end)
C.OnMessage("helpok", function(f, name)
	local h = H.active[f.id]
	if h and h.name == name then H.active[f.id] = nil; ns.Say(L.HELP_DONE, name); ns.Fire("LM_HELP_CHANGED") end   -- only the asker clears it
end)

-- "On my way": whispers the asker (spec §7). Runs only from the board button's click handler.
function H.Coming(id)
	local h = H.active[id]
	if not h then return end
	SendChatMessage(string.format(L.HELP_COMING, (UnitName("player"))), "WHISPER", nil, h.name)
end

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
