-- GuildChat.lua: the guild chat as this client hears it, and a window to read and write it from the book. The lines
-- of this session (guild, officers; a Discord line shows only who wrote, its text is hidden from addons on Forever),
-- newest at the bottom, at most GC.MAX; nothing is saved (as Guild Armory measured, the game's own history is keys,
-- not text). Writing: the box's Enter sends the line to the guild (a key press is a click for the game); a chat
-- lockdown keeps the text in the box. Secret values are skipped.
local _, ns = ...
local GC = {}
ns.GuildChat = GC
local L, SK = ns.L, ns.Skin
GC.MAX = 200
local lines = {}
function GC.Lines() return lines end

local function add(kind, name, text)
	lines[#lines + 1] = { kind = kind, name = name, text = text, at = time() }
	while #lines > GC.MAX do table.remove(lines, 1) end
	ns.Fire("LM_GUILD_CHAT")
end
local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_GUILD"); ev:RegisterEvent("CHAT_MSG_OFFICER"); ev:RegisterEvent("CHAT_MSG_GUILD_DISCORD")
ev:SetScript("OnEvent", function(_, event, text, sender)
	if issecretvalue and issecretvalue(sender) then return end
	local name = ns.ShortName(tostring(sender or "?"))
	if event == "CHAT_MSG_GUILD_DISCORD" then add("discord", name, nil); return end   -- the text is a hidden value for addons
	if (issecretvalue and issecretvalue(text)) or type(text) ~= "string" then return end
	add(event == "CHAT_MSG_OFFICER" and "officer" or "guild", name, text)
end)

------------------------------------------------------------------ the window
local function build()
	local f = SK.Window("LevelMatesGuildChat", UIParent)
	f:SetSize(560, 420); f:SetPoint("CENTER", 200, 0); f:SetFrameStrata("DIALOG")
	f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if UISpecialFrames then table.insert(UISpecialFrames, "LevelMatesGuildChat") end
	if f.TitleText then f.TitleText:SetText(L.GC_TITLE) end
	GC.frame = f
	local msg = GC.MessageFrame(f)
	msg:SetPoint("TOPLEFT", 12, -28); msg:SetPoint("BOTTOMRIGHT", -12, 40)
	GC.msg = msg
	GC.input = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	GC.input:SetHeight(22); GC.input:SetPoint("BOTTOMLEFT", 16, 12); GC.input:SetPoint("RIGHT", -90, 0); GC.input:SetAutoFocus(false); GC.input:SetMaxLetters(255)
	GC.input:SetScript("OnEnterPressed", function(self) if GC.Send(self:GetText()) then self:SetText("") end end)
	GC.input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	GC.send = SK.Button(f)
	GC.send:SetSize(70, 22); GC.send:SetPoint("LEFT", GC.input, "RIGHT", 6, 0); GC.send:SetText(L.GC_SEND)
	GC.send:SetScript("OnClick", function() if GC.Send(GC.input:GetText()) then GC.input:SetText("") end end)
end
local function classColour(name)
	local class = ns.Roster.ClassOf(name)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return string.format("|cff%02x%02x%02x%s|r", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5), name) end
	return name
end
-- A line as text: the hour, the name in its class colour, the words (or that Discord hides them).
function GC.LineText(e)
	local when = date("%H:%M", e.at)
	local body
	if e.kind == "discord" then body = string.format(L.GC_DISCORD_LINE, classColour(e.name))
	elseif e.kind == "officer" then body = L.GC_OFFICER .. " " .. classColour(e.name) .. ": " .. e.text
	else body = classColour(e.name) .. ": " .. e.text end
	return "|cff888888" .. when .. "|r " .. body
end
-- The last n lines, oldest first.
function GC.Last(n)
	local out, first = {}, math.max(1, #lines - n + 1)
	for i = first, #lines do out[#out + 1] = lines[i] end
	return out
end
-- The lines' frame: the game's own chat frame kind, so long lines wrap, the wheel scrolls (Shift: a page) and item
-- links show their tooltip; written in ink, as the rest of the book. The caller places it.
function GC.MessageFrame(parent)
	local msg = CreateFrame("ScrollingMessageFrame", nil, parent)
	msg:SetFontObject(GameFontHighlightSmall or "GameFontHighlightSmall"); msg:SetJustifyH("LEFT")
	msg:SetMaxLines(GC.MAX); msg:SetFading(false); msg:SetIndentedWordWrap(true)
	if msg.SetInsertMode and SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM then msg:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM) end
	msg.lmKeep = true
	msg:EnableMouseWheel(true)
	msg:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then if IsShiftKeyDown and IsShiftKeyDown() then self:PageUp() else self:ScrollUp() end
		else if IsShiftKeyDown and IsShiftKeyDown() then self:PageDown() else self:ScrollDown() end end
	end)
	GC.Hyperlinks(msg)
	return msg
end
-- The lines into a message frame, oldest first, in ink, scrolled to the newest.
function GC.FillMessages(msg, list)
	if not msg then return end
	msg:Clear()
	local r, g, b = SK.Ink(1, 1, 1)
	for _, e in ipairs(list) do msg:AddMessage(SK.ToneText(GC.LineText(e)), r, g, b) end   -- names keep their class colour
	if msg.ScrollToBottom then msg:ScrollToBottom() end
end
-- Item links in a frame's text show their tooltip under the cursor and open on a click, as in the game's chat.
function GC.Hyperlinks(f)
	if not f.SetHyperlinksEnabled then return end
	f:SetHyperlinksEnabled(true)
	f:SetScript("OnHyperlinkEnter", function(self, link)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		if not pcall(GameTooltip.SetHyperlink, GameTooltip, link) then GameTooltip:Hide(); return end
		GameTooltip:Show()
	end)
	f:SetScript("OnHyperlinkLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	f:SetScript("OnHyperlinkClick", function(_, link, text, button) if SetItemRef then pcall(SetItemRef, link, text, button) end end)
end
function GC.Refresh()
	if not GC.frame or not GC.frame:IsShown() then return end
	GC.FillMessages(GC.msg, lines)
end
-- From a box's Enter or a button: to the guild; false (and a word) when a lockdown holds it, so the box keeps it.
function GC.Send(text)
	text = strtrim(tostring(text or ""))
	if text == "" then return false end
	if not ns.SendChat(text, "GUILD") then ns.Say(L.GC_HELD); return false end
	return true
end
function GC.Open()
	if not GC.frame then build() end
	GC.frame:Show()
	GC.Refresh()
end
function GC.Toggle()
	if GC.frame and GC.frame:IsShown() then GC.frame:Hide() else GC.Open() end
end
ns.On("LM_GUILD_CHAT", function() GC.Refresh() end)
ns.Slash("chat", GC.Toggle)
