-- The game's own MOTD on Home and the game's calendar (guild events, player events I am invited to): the next one
-- on Home's Now panel, all of the coming week in Groups > Calendar beside the meetups; asked from the game at login
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
C_GuildInfo.GetMOTD = function() return "Raid el jueves a las 21" end
local now = date("*t")
local tm = date("*t", time() + 86400)
C_DateAndTime = { GetCurrentCalendarTime = function() return { year = now.year, month = now.month, monthDay = now.day, hour = now.hour, minute = now.min } end }
local offsetTomorrow = (tm.year * 12 + tm.month) - (now.year * 12 + now.month)
C_Calendar = {
	OpenCalendar = function() STUB.calendarOpened = true end,
	GetNumDayEvents = function(off, day) if off == offsetTomorrow and day == tm.day then return 2 end; return 0 end,
	GetDayEvent = function(off, day, i)
		if i == 1 then return { title = "Molten Core", calendarType = "GUILD_EVENT", startTime = { year = tm.year, month = tm.month, monthDay = tm.day, hour = 21, minute = 0 }, invitedBy = "Ana" } end
		return { title = "Fiesta de la cerveza", calendarType = "HOLIDAY", startTime = { year = tm.year, month = tm.month, monthDay = tm.day, hour = 0, minute = 0 } }
	end,
}
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, DB, L, CAL = ns.Board, ns.Dashboard, ns.L, ns.Calendar
assert(STUB.calendarOpened, "the calendar asked for at login")
local up = CAL.Upcoming(7)
assert(#up == 1 and up[1].title == "Molten Core" and up[1].kind == "guild" and date("%H:%M", up[1].at) == "21:00", "the guild event, not the holiday: " .. #up)
assert(CAL.When(up[1]):find(L.CAL_TOMORROW, 1, true) and CAL.When(up[1]):find("21:00", 1, true), "when: " .. CAL.When(up[1]))
-- Home: the game's MOTD and the next event
B.Toggle(); B.ShowTab("home")
assert(DB.motd:IsShown() and DB.motd.text.text:find("Raid el jueves", 1, true), "the game's MOTD on Home: " .. tostring(DB.motd.text.text))
local found
for _, it in ipairs(DB.now.items) do if it:IsShown() and it.text.text:find("Molten Core", 1, true) then found = it end end
assert(found and found.text.text:find("21:00", 1, true) and found.action and found.action:IsShown(), "the next event on Now, with a button to the calendar")
-- Groups: the game's calendar under the form, a click opens the game's window
B.ShowTab("lfg"); B.Refresh()
local GV = ns.GroupsView
assert(GV.calPanel and GV.calPanel:IsShown() and GV.calPanel.items[1]:IsShown() and GV.calPanel.items[1].text.text:find("Molten Core", 1, true) and GV.calPanel.items[1].text.text:find("Ana", 1, true), "the event in the Groups view: " .. tostring(GV.calPanel.items[1].text.text))
assert(not GV.calPanel.items[2]:IsShown(), "the holiday is not listed")
-- the game saying the list changed redraws the page
STUB.calendarOpened = nil
STUB.Fire("CALENDAR_UPDATE_EVENT_LIST"); STUB.Advance(1)
print("ok")
