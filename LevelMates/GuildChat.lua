-- GuildChat.lua: the guild chat, with its history, and a window to read and write it from the book. The lines come
-- from three places and merge in time order, at most GC.MAX: the history the game itself keeps for the guild and
-- officer streams (C_Club; read at login and whenever the game downloads more, asked for backwards the way the
-- game's own window does); what this client hears live (guild, officers; a Discord line shows only who wrote, its
-- text is hidden from addons on Forever); and what was saved from the last session, for when the game gives
-- nothing. Writing: the box's Enter sends the line to the guild (a key press is a click for the game); a chat
-- lockdown keeps the text in the box. Secret values are skipped.
local _, ns = ...
local GC = {}
ns.GuildChat = GC
local L, SK = ns.L, ns.Skin
GC.MAX = 200
GC.ASK = 200   -- how many older lines to ask the game for
local lines = {}
local seen = {}   -- the game's message ids already in the list
function GC.Lines() return lines end

local function plain(v) if issecretvalue and issecretvalue(v) then return nil end; return v end
local function trim()
	while #lines > GC.MAX do local gone = table.remove(lines, 1); if gone.id then seen[gone.id] = nil end end
end
local function save()
	if not ns.db then return end
	ns.db.chat = ns.db.chat or {}
	local out = {}
	for _, e in ipairs(lines) do out[#out + 1] = { k = e.kind, n = e.name, x = e.text, t = e.at, i = e.id } end
	ns.db.chat[ns.GuildKey()] = out
end
local function same(a, b) return a.name == b.name and a.text == b.text and a.kind == b.kind and math.abs((a.at or 0) - (b.at or 0)) <= 120 end
-- A line into the list, in time order; a line already there (by the game's id, or the same words from the same
-- person within two minutes, as a live line later found in the history) is not added twice.
local function put(e)
	if e.id then
		if seen[e.id] then return false end
		for _, old in ipairs(lines) do if not old.id and same(old, e) then old.id = e.id; seen[e.id] = true; return false end end
		seen[e.id] = true
	else
		for i = #lines, math.max(1, #lines - 20), -1 do if same(lines[i], e) then return false end end
	end
	local at = #lines + 1
	while at > 1 and (lines[at - 1].at or 0) > (e.at or 0) do at = at - 1 end
	table.insert(lines, at, e)
	return true
end
local function add(kind, name, text)
	put({ kind = kind, name = name, text = text, at = time() })
	trim(); save()
	ns.Fire("LM_GUILD_CHAT")
end

------------------------------------------------------------------ the game's own history
local STREAM_KIND = { [1] = "guild", [2] = "officer" }   -- Enum.ClubStreamType.Guild / Officer
local function guildStreams()
	if not (C_Club and C_Club.GetGuildClubId and C_Club.GetStreams) then return nil end
	local club = plain(C_Club.GetGuildClubId())
	if not club then return nil end
	local ok, streams = pcall(C_Club.GetStreams, club)
	local out = {}
	for _, s in ipairs(ok and ns.List(streams) or {}) do
		local kind = STREAM_KIND[plain(s.streamType)]
		local id = plain(s.streamId)
		if kind and id then out[#out + 1] = { club = club, id = id, kind = kind } end
	end
	return out
end
-- The newest GC.MAX lines the game holds for a stream: { kind, name, text, at, id, class }; placeholders for
-- lines the game has not loaded ("Unknown"), destroyed lines and secret values are left out.
local function readStream(s)
	if not (C_Club.GetMessageRanges and C_Club.GetMessagesInRange) then return {} end
	local okR, ranges = pcall(C_Club.GetMessageRanges, s.club, s.id)
	ranges = okR and ns.List(ranges) or {}
	local out = {}
	for r = #ranges, 1, -1 do
		if #out >= GC.MAX then break end
		local range = ranges[r]
		local oldest, newest = plain(range.oldestMessageId), plain(range.newestMessageId)
		local okM, messages = false, nil
		if oldest and newest then okM, messages = pcall(C_Club.GetMessagesInRange, s.club, s.id, oldest, newest) end
		messages = okM and ns.List(messages) or {}
		for i = #messages, 1, -1 do
			if #out >= GC.MAX then break end
			local m = messages[i]
			local mid = plain(m.messageId)
			local epoch = mid and plain(mid.epoch)
			local text = plain(m.content)
			local author = plain(m.author)
			local name = author and plain(author.name)
			if epoch and type(text) == "string" and text ~= "" and text ~= UNKNOWN and not plain(m.destroyed) and type(name) == "string" and name ~= "" then
				out[#out + 1] = { kind = s.kind, name = ns.ShortName(name), text = text, at = math.floor(tonumber(epoch) / 1000000),
					id = string.format("%.0f", tonumber(epoch)) .. ":" .. tostring(plain(mid.position) or 0), class = author and plain(author.classID) or nil }
			end
		end
	end
	return out
end
-- The game's history into the list (new lines only); true when something was added.
function GC.LoadHistory()
	local streams = guildStreams()
	if not streams then return false end
	local added = false
	for _, s in ipairs(streams) do
		for _, e in ipairs(readStream(s)) do if put(e) then added = true end end
	end
	if added then trim(); save(); ns.Fire("LM_GUILD_CHAT") end
	return added
end
-- Ask the game for older lines, the way its own window does: subscribe, focus the stream, then ask for what
-- comes before the newest line it holds. The answer arrives as CLUB_MESSAGE_HISTORY_RECEIVED.
function GC.RequestHistory()
	local streams = guildStreams()
	if not streams or not C_Club.RequestMoreMessagesBefore then return false end
	for _, s in ipairs(streams) do
		if C_Club.SetClubPresenceSubscription then pcall(C_Club.SetClubPresenceSubscription, s.club) end
		if C_Club.FocusStream then pcall(C_Club.FocusStream, s.club, s.id) end
		local newest
		local okR, ranges = pcall(C_Club.GetMessageRanges, s.club, s.id)
		ranges = okR and ns.List(ranges) or {}
		if #ranges > 0 then newest = plain(ranges[#ranges].newestMessageId) end
		pcall(C_Club.RequestMoreMessagesBefore, s.club, s.id, newest, GC.ASK)
	end
	return true
end
-- What the last session saved, for when the game has nothing to give (never over what it does give).
local function loadSaved()
	local saved = ns.db and ns.db.chat and ns.db.chat[ns.GuildKey()]
	for _, e in ipairs(saved or {}) do put({ kind = e.k, name = e.n, text = e.x, at = e.t, id = e.i }) end
	trim()
end
ns.On("LM_WORLD", function()
	loadSaved()
	C_Timer.After(3, function() GC.LoadHistory(); GC.RequestHistory() end)
end)
local hist = CreateFrame("Frame")
hist:RegisterEvent("CLUB_MESSAGE_HISTORY_RECEIVED"); hist:RegisterEvent("CLUB_MESSAGE_ADDED")
hist:SetScript("OnEvent", function() GC.LoadHistory() end)
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
-- The lines into a message frame, oldest first, names in their class colour (toned for the page). New lines at
-- the end are appended, so the view stays where the reader left it; anything else (older lines arriving, a line
-- gone) rewrites the frame. The view follows the newest line only while it was already at the bottom.
function GC.FillMessages(msg, list)
	if not msg then return end
	local r, g, b = SK.Ink(1, 1, 1)
	local shown = msg.lmShown or {}
	local keep = #shown > 0 and #list >= #shown
	for i = 1, #shown do if not keep or list[i] ~= shown[i] then keep = false; break end end
	local wasAtBottom = not msg.AtBottom or msg:AtBottom()
	local from = 1
	if keep then from = #shown + 1 else msg:Clear(); shown = {} end
	for i = from, #list do msg:AddMessage(SK.ToneText(GC.LineText(list[i])), r, g, b); shown[i] = list[i] end
	msg.lmShown = shown
	if (wasAtBottom or not keep) and msg.ScrollToBottom then msg:ScrollToBottom() end
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
