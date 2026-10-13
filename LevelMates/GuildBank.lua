-- GuildBank.lua: what is in the guild bank, read by whoever opens it (the tabs they can see) and shared when they
-- close it, so everyone knows without going there. A board record `gbk` (id "bank"), the newest wins.
-- Spec 2026-10-12-levelmates-guild-design (2).
local _, ns = ...
local GB = {}
ns.GuildBank = GB
local L, C, S = ns.L, ns.Comm, ns.Sync
GB.SLOTS, GB.QUERY_GAP, GB.SETTLE, GB.LIFE = 98, 0.4, 1.2, 30 * 86400

-- Tabs on the wire: "name~id:n,id:n^name~…"; the separators are taken out of tab names.
local function cleanName(s) return (tostring(s or ""):gsub("[~%^,:%c|]", " ")) end
function GB.Encode(tabs)
	local parts = {}
	for _, tab in ipairs(tabs) do
		local items = {}
		for id, n in pairs(tab.items) do items[#items + 1] = id .. ":" .. n end
		table.sort(items)
		parts[#parts + 1] = cleanName(tab.name) .. "~" .. table.concat(items, ",")
	end
	return table.concat(parts, "^")
end
function GB.Decode(p)
	if type(p) ~= "string" then return nil end
	local tabs = {}
	for part in (p .. "^"):gmatch("([^%^]*)%^") do
		if part ~= "" then
			local name, list = part:match("^([^~]*)~(.*)$")
			if not name then return nil end
			local items = {}
			for id, n in list:gmatch("(%d+):(%d+)") do items[tonumber(id)] = tonumber(n) end
			tabs[#tabs + 1] = { name = name, items = items }
		end
	end
	return tabs
end

local function wire(v) return type(v) == "string" and #v <= 14000 and not v:find("[%c|]") end   -- eight full tabs; under the blob limit
S.Define("gbk", { class = "board", life = GB.LIFE, writerOwns = true,
	fields = { t = C.V.int(0, 4000000000), m = C.V.int(0, 9000000000000), p = wire }, required = { "t", "p" },
	may = function() return true end,   -- whoever opened the bank last tells what is in it
	accept = function(f) return f.t <= GetServerTime() + 300 and GB.Decode(f.p) ~= nil end,   -- a clock from the future is wrong
	onChange = function() ns.Fire("LM_BANK_CHANGED") end })

-- The latest snapshot I know: { t, m, by, tabs } or nil (what I am reading right now, with the bank open).
local read
function GB.Snapshot()
	if read then return { t = GetServerTime(), m = read.m, by = ns.Me(), tabs = read.tabs } end
	local r = S.Get("gbk", "bank")
	if not r then return nil end
	local tabs = GB.Decode(r.d.p)
	return tabs and { t = r.d.t, m = r.d.m or 0, by = r.o, tabs = tabs }
end
-- One row per item: { id, n, tab }, of what the search names (item name or number).
function GB.Rows(search)
	local s, out, q = GB.Snapshot(), {}, strtrim(tostring(search or "")):lower()
	if not s then return out end
	for _, tab in ipairs(s.tabs) do
		for id, n in pairs(tab.items) do
			local name = ns.ItemInfo(id)
			if q == "" or tostring(id) == q or (name and name:lower():find(q, 1, true)) then out[#out + 1] = { id = id, n = n, tab = tab.name } end
		end
	end
	table.sort(out, function(a, b) if a.tab ~= b.tab then return a.tab < b.tab end; return a.id < b.id end)
	return out
end

-- Reading: ask the server for each tab I can see, 0.4 s apart, then read them all once it has been quiet 1.2 s.
-- A tab that came back empty keeps what the last snapshot had (it may not have loaded).
local reading = nil
local function readTabs()
	local last = GB.Snapshot()
	local before = {}
	for _, tab in ipairs(last and last.tabs or {}) do before[tab.name] = tab.items end
	local tabs = {}
	for t = 1, GetNumGuildBankTabs() do
		local name, _, viewable = GetGuildBankTabInfo(t)
		if viewable then
			local items, any = {}, false
			for slot = 1, GB.SLOTS do
				local link = GetGuildBankItemLink(t, slot)
				local id = link and tonumber(link:match("item:(%d+)") or "")
				if id then
					local _, count = GetGuildBankItemInfo(t, slot)
					items[id] = (items[id] or 0) + (count or 1); any = true
				end
			end
			if not any and before[cleanName(name)] then items = before[cleanName(name)] end
			tabs[#tabs + 1] = { name = cleanName(name), items = items }
		end
	end
	-- tabs I cannot see (lower rank) stay as the last snapshot had them: never wiped for everyone
	local have = {}
	for _, tab in ipairs(tabs) do have[tab.name] = true end
	for _, tab in ipairs(last and last.tabs or {}) do if not have[tab.name] then tabs[#tabs + 1] = tab end end
	read = { tabs = tabs, m = GetGuildBankMoney and GetGuildBankMoney() or 0 }
end
local function open()
	reading = GetTime()
	local n = GetNumGuildBankTabs and GetNumGuildBankTabs() or 0
	for t = 1, n do C_Timer.After((t - 1) * GB.QUERY_GAP, function() if QueryGuildBankTab then QueryGuildBankTab(t) end end) end
	local stamp = reading
	C_Timer.After(n * GB.QUERY_GAP + GB.SETTLE, function() if reading == stamp then readTabs() end end)
end
local function close()
	reading = nil
	if not read then return end
	if ns.db.settings.shareBank then
		S.Put("gbk", "bank", { t = GetServerTime(), m = read.m, p = GB.Encode(read.tabs) })
	end
	read = nil
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("GUILDBANKFRAME_OPENED"); ev:RegisterEvent("GUILDBANKFRAME_CLOSED")
ev:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW"); ev:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
local BANKER = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker or 10
ev:SetScript("OnEvent", function(_, event, kind)
	if event == "GUILDBANKFRAME_OPENED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and kind == BANKER) then open()
	elseif event == "GUILDBANKFRAME_CLOSED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and kind == BANKER) then
		if reading and not read then readTabs() end   -- closed before the wait was over: read what loaded
		close()
	end
end)
