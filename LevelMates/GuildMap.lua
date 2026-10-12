-- GuildMap.lua: guildmates who share their position, as class-icon pins on the world map being shown, and the
-- busiest zone for the Guildmates tab. Spec 2026-10-10-levelmates-social-leveling-design (B3).
local _, ns = ...
local GM = {}
ns.GuildMap = GM
local L, R = ns.L, ns.Roster
GM.pins = {}
local SIZE = 16

local function pin(i)
	local p = GM.pins[i]
	if p then return p end
	p = CreateFrame("Button", nil, WorldMapFrame:GetCanvas())
	p:SetSize(SIZE, SIZE); p:SetFrameStrata("HIGH")
	p.icon = p:CreateTexture(nil, "OVERLAY"); p.icon:SetAllPoints()
	p:SetScript("OnEnter", function(self)
		local m = R.mates[self.mate]
		if not (GameTooltip and m) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(string.format("%s (%d)", self.mate, m.level or 0), 1, 1, 1)
		GameTooltip:Show()
	end)
	p:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	GM.pins[i] = p
	return p
end

local function classIcon(tex, class)
	local atlas = class and ("classicon-" .. class:lower())
	if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then tex:SetAtlas(atlas) return end
	tex:SetTexture("Interface\\Minimap\\PartyRaidBlips"); tex:SetTexCoord(0.875, 1, 0.25, 0.5)   -- a plain dot
end

function GM.Refresh()
	if not WorldMapFrame or not WorldMapFrame.GetCanvas then return end
	local canvas, mapId, i = WorldMapFrame:GetCanvas(), WorldMapFrame:GetMapID(), 0
	if ns.db.settings.mapPins and WorldMapFrame:IsShown() then
		for name, m in pairs(R.mates) do
			if m.mapId == mapId and m.x and m.y then
				i = i + 1
				local p = pin(i)
				p.mate = name
				classIcon(p.icon, m.class)
				p:ClearAllPoints()
				p:SetPoint("CENTER", canvas, "TOPLEFT", canvas:GetWidth() * m.x / 100, -canvas:GetHeight() * m.y / 100)
				p:Show()
			end
		end
	end
	for j = i + 1, #GM.pins do GM.pins[j]:Hide() end
end

-- The zone with most guildmates online (me included), when two or more share it.
function GM.Busiest()
	local counts = {}
	local mine = C_Map.GetBestMapForUnit("player")
	if mine then counts[mine] = 1 end
	for _, m in pairs(R.mates) do if m.mapId and m.mapId > 0 then counts[m.mapId] = (counts[m.mapId] or 0) + 1 end end
	local best, bestN = nil, 1
	for id, n in pairs(counts) do if n > bestN or (n == bestN and best and id < best) then best, bestN = id, n end end
	return best and bestN or 0, best
end

local hooked = false
local function hook()
	if hooked or not WorldMapFrame or not WorldMapFrame.OnMapChanged then return end
	hooked = true
	hooksecurefunc(WorldMapFrame, "OnMapChanged", GM.Refresh)
	WorldMapFrame:HookScript("OnShow", GM.Refresh)
end
ns.On("LM_WORLD", hook)
ns.On("LM_ROSTER_CHANGED", function() if WorldMapFrame and WorldMapFrame:IsShown() then GM.Refresh() end end)
ns.On("LM_MATE_MOVED", function() if WorldMapFrame and WorldMapFrame:IsShown() then GM.Refresh() end end)   -- a position alone
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, _, name) if name == "Blizzard_WorldMap" then hook() end end)

------------------------------------------------------------------ layout
-- Where each guildmate goes on the map being viewed: their zone position as is on that zone's map, or converted
-- through world coordinates onto a continent (or any map that holds their zone); positions older than five minutes
-- are left out; four or more within one pin's size become a bundle. { { x, y, names, mapId, mx, my } } in canvas
-- pixels (mapId, mx, my: where the first of them is, for a route). Me: counted for bundles, never drawn.
GM.STALE, GM.BUNDLE = 300, 4
local function project(from, x, y, to)
	if from == to then return x, y end
	if not (C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
	local ok, a, b = pcall(C_Map.GetWorldPosFromMapPos, from, CreateVector2D(x, y))
	if not ok then return nil end
	local cont, world = a, b
	if type(a) == "table" then cont, world = 0, a end
	if type(world) ~= "table" then return nil end
	local ok2, c, d = pcall(C_Map.GetMapPosFromWorldPos, cont, world, to)
	if not ok2 then return nil end
	local pos = type(d) == "table" and d or (type(c) == "table" and c) or nil
	if not pos then return nil end
	local px, py
	if pos.GetXY then px, py = pos:GetXY() else px, py = pos.x, pos.y end
	if not px or not py or px < 0 or px > 1 or py < 0 or py > 1 then return nil end
	return px, py
end
function GM.Layout(mapId, w, h, pinPx)
	local points, now = {}, GetTime()
	for name, m in pairs(R.mates) do
		if m.x and m.y and m.mapId and (now - (m.posAt or 0)) <= GM.STALE then
			local px, py = project(m.mapId, m.x / 100, m.y / 100, mapId)
			if px then points[#points + 1] = { x = px * w, y = py * h, name = name, mapId = m.mapId, mx = m.x, my = m.y } end
		end
	end
	local myMap = C_Map.GetBestMapForUnit("player")
	local myPos = myMap and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(myMap, "player")
	if myPos then
		local mx, my = myPos:GetXY()
		local px, py = project(myMap, mx, my, mapId)
		if px then points[#points + 1] = { x = px * w, y = py * h, me = true } end
	end
	table.sort(points, function(a, b)
		if a.y ~= b.y then return a.y < b.y end
		if a.x ~= b.x then return a.x < b.x end
		return (a.name or "") < (b.name or "")
	end)
	local used, out = {}, {}
	for i, p in ipairs(points) do
		if not used[i] then
			local near = { i }
			for j = i + 1, #points do
				if not used[j] then
					local dx, dy = points[j].x - p.x, points[j].y - p.y
					if dx * dx + dy * dy <= pinPx * pinPx then near[#near + 1] = j end
				end
			end
			if #near >= GM.BUNDLE then
				local sx, sy, names, first = 0, 0, {}, nil
				for _, j in ipairs(near) do
					used[j] = true
					local q = points[j]
					sx, sy = sx + q.x, sy + q.y
					if not q.me then names[#names + 1] = q.name; first = first or q end
				end
				table.sort(names)
				if #names > 0 then out[#out + 1] = { x = sx / #near, y = sy / #near, names = names, mapId = first.mapId, mx = first.mx, my = first.my } end
			else
				used[i] = true
				if not p.me then out[#out + 1] = { x = p.x, y = p.y, names = { p.name }, mapId = p.mapId, mx = p.mx, my = p.my } end
			end
		end
	end
	return out
end
