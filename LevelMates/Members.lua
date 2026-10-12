-- Members.lua: the rows of the Members sub-tab: the whole guild list (with or without LevelMates) with rank, level,
-- zone or last seen and the shared note; the alts tree; the race. Spec 2026-10-12-levelmates-guild-design (1).
local _, ns = ...
local MB = {}
ns.Members = MB
local R = ns.Roster
local OFFLINE = 3   -- Enum.ClubMemberPresence.Offline

-- The guild list, read at most every 30 s: { name, level, rank, role, online, zone, note }.
local cache, cachedAt = nil, -math.huge
local function roster()
	if cache and GetTime() - cachedAt < 30 then return cache end
	cache, cachedAt = {}, GetTime()
	local club = C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
	if not club then return cache end
	for _, id in ipairs(C_Club.GetClubMembers(club) or {}) do
		local info = C_Club.GetMemberInfo(club, id)
		if info and info.name then
			cache[#cache + 1] = { name = info.name, level = info.level or 0, rank = info.guildRankOrder or 0, role = info.role,
				online = info.presence ~= OFFLINE, zone = info.zone, days = info.lastOnlineYear and ((info.lastOnlineYear or 0) * 365 + (info.lastOnlineMonth or 0) * 30 + (info.lastOnlineDay or 0)) }
		end
	end
	return cache
end
function MB.Invalidate() cache = nil end
ns.On("LM_HISTORY_CHANGED", MB.Invalidate)

-- filter: "all", "online", "officers" (guild master and officers), "nonote"; search: name or note.
function MB.List(filter, search)
	local q, out = strtrim(tostring(search or "")):lower(), {}
	for _, m in ipairs(roster()) do
		local note = ns.GuildNotes.Note(m.name)
		local keep = (filter == nil or filter == "all")
			or (filter == "online" and m.online)
			or (filter == "officers" and (m.role == 1 or m.role == 2))
			or (filter == "nonote" and not note)
		if keep and (q == "" or m.name:lower():find(q, 1, true) or (note and note:lower():find(q, 1, true))) then
			local e = { name = m.name, level = m.level, rank = m.rank, role = m.role, online = m.online, zone = m.zone, days = m.days, note = note }
			out[#out + 1] = e
		end
	end
	table.sort(out, function(a, b)
		if a.online ~= b.online then return a.online end
		if a.rank ~= b.rank then return a.rank < b.rank end
		if a.level ~= b.level then return a.level > b.level end
		return a.name < b.name
	end)
	return out
end

-- The alts tree: each main (the highest level of the family) with the others under it; "proven" for mine (same
-- account), "said" for what someone shares about themselves.
function MB.Alts()
	local out, seen = {}, {}
	local function family(main, alts, proven)
		out[#out + 1] = { main = main, proven = proven }
		for _, a in ipairs(alts) do out[#out + 1] = { alt = a, of = main, proven = proven }; seen[a] = true end
		seen[main] = true
	end
	local mine = ns.Alts.MyAlts()
	if #mine > 0 then
		local names = {}
		for _, c in ipairs(mine) do names[#names + 1] = c.name end
		family(ns.Me(), names, true)
	end
	for _, m in ipairs(roster()) do
		if not seen[m.name] then
			local alts = ns.Alts.Of(m.name)
			if #alts > 0 then family(m.name, alts, false) end
		end
	end
	return out
end

function MB.RaceRows() return ns.GuildHistory.Race() end
