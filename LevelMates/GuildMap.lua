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
