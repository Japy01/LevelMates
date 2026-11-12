-- Raid-scoped export of the existing loot book. Includes cancellations, corrections and refunds.
-- No second ledger, stored snapshot, messages or filesystem writes.
local _, ns = ...
local E = {}
ns.LootExport = E
local L, S = ns.L, ns.Sync
local COLUMNS = { "record_type", "entry_kind", "record_id", "recorded_at", "author", "raid_id", "player", "item_id", "points", "cost", "state", "proof", "boss", "encounter", "reference", "spend_id", "reason" }
function E.Raids()
	local out, seen = {}, {}
	for _, kind in ipairs({ "lk", "la" }) do
		for _, r in ipairs(S.List(kind)) do
			if r.d.g and not seen[r.d.g] then seen[r.d.g] = true; out[#out + 1] = r.d.g end
		end
	end
	table.sort(out)
	return out
end
function E.Rows(raidId)
	if type(raidId) ~= "string" or not ns.Comm.V.word(24)(raidId) then return nil end
	local rows = {}
	for _, kind in ipairs({ "lk", "la" }) do
		for _, r in ipairs(S.List(kind)) do
			local d = r.d
			if d.g == raidId then
				rows[#rows + 1] = { record_type = kind, entry_kind = kind == "lk" and d.k or nil, record_id = r.id, recorded_at = kind == "la" and (d.at or r.v) or r.v,
					author = r.o, raid_id = d.g, player = kind == "la" and d.to or d.w, item_id = d.i,
					points = d.p, cost = d.c, state = d.s, proof = d.pf, boss = d.b, encounter = d.en,
					reference = d.f, spend_id = d.k, reason = d.r }
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.recorded_at ~= b.recorded_at then return a.recorded_at < b.recorded_at end
		if a.record_type ~= b.record_type then return a.record_type < b.record_type end
		return a.record_id < b.record_id
	end)
	return rows
end
local function csv(value)
	if value == nil then return '""' end
	if type(value) == "number" then return tostring(value) end
	value = tostring(value)
	-- Imported text must not become a spreadsheet formula. Numeric ledger amounts stay numeric.
	if value:find("^%s*[=+@%-]") then value = "'" .. value end
	return '"' .. value:gsub('"', '""') .. '"'
end
function E.CSV(raidId)
	local rows = E.Rows(raidId)
	if not rows then return nil end
	local lines = { table.concat(COLUMNS, ",") }
	for _, row in ipairs(rows) do
		local cells = {}; for _, key in ipairs(COLUMNS) do cells[#cells + 1] = csv(row[key]) end
		lines[#lines + 1] = table.concat(cells, ",")
	end
	return table.concat(lines, "\r\n") .. "\r\n", #rows
end
function E.Text(raidId)
	local rows = E.Rows(raidId)
	if not rows then return nil end
	local lines = { string.format(L.RAID_EXPORT_TITLE, raidId), L.RAID_EXPORT_LIMITS }
	for _, row in ipairs(rows) do
		local detail
		if row.record_type == "lk" then
			detail = string.format("%s · %s · %s · %s · %s", row.player or "?", row.entry_kind or "?", tostring(row.points or 0), row.reason or "", row.reference or "")
		else
			detail = string.format("#%s → %s · %s · %s · %s", tostring(row.item_id or "?"), row.player or "?", row.state or "?", row.proof or "?", row.boss or "?")
		end
		lines[#lines + 1] = string.format("%s [%s:%s] %s (%s)", date("%d/%m %H:%M", row.recorded_at), row.record_type, row.record_id, detail, row.author or "?")
	end
	if #rows == 0 then lines[#lines + 1] = L.RAID_EXPORT_EMPTY end
	return table.concat(lines, "\n"), #rows
end
ns.Slash("raidexport", function(rest)
	local id, format = strtrim(rest or ""):match("^(%S+)%s*(%S*)$")
	if not id then
		ns.DiscordCopy.OpenText(L.RAID_EXPORT_HELP .. "\n" .. table.concat(E.Raids(), "\n")); return
	end
	local text
	if format == "csv" then text = E.CSV(id)
	elseif format == "" or format == "text" then text = E.Text(id) end
	ns.DiscordCopy.OpenText(text or L.RAID_EXPORT_HELP)
end)
