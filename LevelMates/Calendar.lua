-- Calendar.lua: the game's own calendar, read for the guild: guild events and announcements, and player events I
-- am invited to, in the coming days. Shown on Home (the next one) and in Groups > Calendar beside the meetups.
-- The game loads the events once the calendar has been asked for (OpenCalendar), and says when they change.
local _, ns = ...
local CAL = {}
ns.Calendar = CAL
local L = ns.L
CAL.DAYS = 7
local KINDS = { GUILD_EVENT = "guild", GUILD_ANNOUNCEMENT = "guild", PLAYER = "player" }

local function plain(v) return ns.Plain(v) end
-- Month offset and day for a date n days from today, by the game's own calendar clock.
local function today()
	local ok, t = pcall(function() return C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime() end)
	t = ok and plain(t) or nil
	if type(t) ~= "table" then return nil end
	local y, m, d = plain(t.year), plain(t.month), plain(t.monthDay)
	if not (y and m and d) then return nil end
	return { year = y, month = m, day = d, hour = plain(t.hour) or 0, min = plain(t.minute) or 0 }
end
-- The events of the coming days, soonest first: { title, at (seconds), kind, invitedBy, day }.
function CAL.Upcoming(days)
	local out = {}
	if not (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent) then return out end
	local now = today()
	if not now then return out end
	local base = time({ year = now.year, month = now.month, day = now.day, hour = 12 })
	for n = 0, (days or CAL.DAYS) do
		local d = date("*t", base + n * 86400)
		local offset = (d.year * 12 + d.month) - (now.year * 12 + now.month)
		local okN, count = pcall(C_Calendar.GetNumDayEvents, offset, d.day)
		count = okN and plain(count) or 0
		for i = 1, count do
			local okE, e = pcall(C_Calendar.GetDayEvent, offset, d.day, i)
			e = okE and plain(e) or nil
			local kind = type(e) == "table" and KINDS[plain(e.calendarType) or ""]
			local title = kind and plain(e.title)
			if kind and type(title) == "string" and title ~= "" then
				local st = plain(e.startTime)
				local hour, min = st and plain(st.hour) or 0, st and plain(st.minute) or 0
				local at = time({ year = d.year, month = d.month, day = d.day, hour = hour, min = min })
				if at >= time() - 3600 then out[#out + 1] = { title = title, at = at, kind = kind, invitedBy = plain(e.invitedBy), day = d.year * 10000 + d.month * 100 + d.day } end
			end
		end
	end
	table.sort(out, function(a, b) return a.at < b.at end)
	return out
end
-- "mañana 21:00" / "jue 21:00".
function CAL.When(e)
	local t = date("*t", e.at)
	local function key(d) return d.year * 10000 + d.month * 100 + d.day end
	local dayWord
	if key(t) == key(date("*t")) then dayWord = L.CAL_TODAY
	elseif key(t) == key(date("*t", time() + 86400)) then dayWord = L.CAL_TOMORROW
	else dayWord = L["DAY_" .. t.wday] or "" end
	return string.format("%s %02d:%02d", dayWord, t.hour, t.min)
end
-- The game's calendar window (a click).
function CAL.Open() if ToggleCalendar then pcall(ToggleCalendar) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
ev:SetScript("OnEvent", function() ns.Fire("LM_CALENDAR_CHANGED"); ns.Dirty("board") end)
ns.On("LM_WORLD", function() if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end end)
