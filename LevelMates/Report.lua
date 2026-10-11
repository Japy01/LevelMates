-- Report.lua: /lm informe opens a box with what is needed to understand a problem (versions, guild, messages,
-- guildmates seen, points, changed options, LevelMates' last errors), to copy and paste to whoever helps. Nothing is
-- sent anywhere.
local _, ns = ...
local RP = {}
ns.Report = RP
local L = ns.L
RP.KEEP = 5
local errors = {}

-- LevelMates' own errors, caught where they start (ns.Fire runs every listener under xpcall): the game's error
-- handler is left alone, so no addon code runs inside it.
function ns.OnError(msg)
	if issecretvalue and issecretvalue(msg) then return end
	errors[#errors + 1] = (date and date("%H:%M") or "") .. " " .. tostring(msg)
	while #errors > RP.KEEP do table.remove(errors, 1) end
end

function RP.Text()
	local lines = {}
	local function add(fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end
	local build, number = GetBuildInfo()
	add("LevelMates %s · WoW %s (%s) · %s", tostring(ns.VERSION), tostring(build), tostring(number), GetLocale())
	add("%s: %s", L.REPORT_GUILD, IsInGuild() and (GetGuildInfo("player") or "?") or "-")
	local s = ns.Comm.stats
	add("%s: %s · %d/%d/%d (%s) · %d %s", L.REPORT_MESSAGES, ns.Comm.ActiveTransport(), s.sent, s.received, s.bad, L.REPORT_SRB, s.queued, L.REPORT_QUEUED)
	-- how many guildmates and which versions they run (no names: the report may be pasted in public)
	local versions, count = {}, 0
	for _, name in ipairs(ns.Roster.List()) do
		local v = tostring(ns.Roster.mates[name].version or "?")
		versions[v] = (versions[v] or 0) + 1
		count = count + 1
	end
	local parts = {}
	for v, k in pairs(versions) do parts[#parts + 1] = v .. " ×" .. k end
	table.sort(parts)
	add("%s (%d): %s", L.REPORT_MATES, count, #parts > 0 and table.concat(parts, ", ") or "-")
	local p = ns.Points.Mine()
	add("%s: %d · %s %d", L.REPORT_POINTS, p.t, L.REPORT_GUILD_TOTAL, ns.Points.GuildTotal())
	local changed = {}
	for k, v in pairs(ns.db.settings) do
		if ns.DEFAULTS[k] ~= nil and ns.DEFAULTS[k] ~= v then changed[#changed + 1] = k .. "=" .. tostring(v) end
	end
	table.sort(changed)
	add("%s: %s", L.REPORT_OPTIONS, #changed > 0 and table.concat(changed, ", ") or "-")
	add("%s:", L.REPORT_ERRORS)
	if #errors == 0 then add("  -") else for _, e in ipairs(errors) do add("  %s", e) end end
	return table.concat(lines, "\n")
end

ns.Slash("informe", function() ns.DiscordCopy.OpenText(RP.Text()) end)
ns.Slash("report", function() ns.DiscordCopy.OpenText(RP.Text()) end)
