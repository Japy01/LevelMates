-- MinimapButton.lua: a button on the minimap edge. Left click shows or hides the board, right click opens the
-- options, drag moves it around the minimap (angle saved account-wide). The options switch shows or hides it.
local _, ns = ...
local M = {}
ns.MinimapButton = M
local L = ns.L
local atan2 = math.atan2 or math.atan   -- the client's Lua 5.1 has atan2; newer Lua folds it into atan

-- Angle in degrees (0 = right, 90 = up) from the minimap centre to the cursor, both in the same units.
function M.AngleFromCursor(cx, cy, mx, my)
	return math.deg(atan2(cy - my, cx - mx)) % 360
end

-- Where the button goes for an angle: on the circle; on a square minimap (the shape minimap addons declare), along
-- the square's edge, so the button never floats inside the map or hangs off a corner.
function M.Offset(angle, half, shape)
	local rad = math.rad(angle)
	local x, y = math.cos(rad), math.sin(rad)
	if shape == "SQUARE" then
		local k = math.max(math.abs(x), math.abs(y))
		if k > 0 then x, y = x / k, y / k end
		return x * half, y * half
	end
	return x * (half + 5), y * (half + 5)
end
function M.Place(angle)
	local b = M.button
	if not b then return end
	local shape = Minimap.GetMinimapShape and Minimap:GetMinimapShape() or (GetMinimapShape and GetMinimapShape()) or "ROUND"
	local x, y = M.Offset(angle, Minimap:GetWidth() / 2, shape)
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function M.Refresh()
	if not M.button then return end
	M.button:SetShown(ns.db.settings.minimap ~= false)
end

local function Build()
	local b = CreateFrame("Button", "LevelMatesMinimapButton", Minimap)
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface/AddOns/LevelMates/Media/icon"); icon:SetSize(20, 20); icon:SetPoint("CENTER", 0, 1)
	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder"); border:SetSize(53, 53); border:SetPoint("TOPLEFT")
	b:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight", "ADD")

	b:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then ns.Settings.Open()
		elseif IsShiftKeyDown and IsShiftKeyDown() then ns.Tray.Open()   -- Shift+click: the tray of notices
		else ns.Fire("LM_TOGGLE_BOARD") end
	end)
	b:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local scale = Minimap:GetEffectiveScale()
			local cx, cy = GetCursorPosition()
			local mx, my = Minimap:GetCenter()
			ns.db.settings.minimapAngle = M.AngleFromCursor(cx / scale, cy / scale, mx, my)
			M.Place(ns.db.settings.minimapAngle)
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(L.BOARD_TITLE)
		GameTooltip:AddLine(L.MINIMAP_LEFT); GameTooltip:AddLine(L.MINIMAP_SHIFT); GameTooltip:AddLine(L.MINIMAP_RIGHT); GameTooltip:AddLine(L.MINIMAP_DRAG)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	M.button = b
	-- the unread notices, on the button's corner
	local badge = CreateFrame("Frame", nil, b)
	badge:SetSize(16, 16); badge:SetPoint("TOPRIGHT", 2, 2); badge:SetFrameLevel(b:GetFrameLevel() + 2)
	badge.bg = badge:CreateTexture(nil, "BACKGROUND"); badge.bg:SetAllPoints(); badge.bg:SetTexture("Interface/Minimap/UI-Minimap-Background"); badge.bg:SetVertexColor(0.6, 0.05, 0.05)
	badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	badge.text:SetPoint("CENTER", 0, 0)
	badge:Hide()
	M.badge = badge
end

function M.UpdateBadge()
	if not M.badge then return end
	local n = ns.Tray.Unread()
	M.badge.text:SetText(tostring(n))
	M.badge:SetShown(n > 0)
end
ns.On("LM_TRAY_CHANGED", function() M.UpdateBadge() end)

ns.On("LM_LOADED", function()
	if not Minimap then return end
	Build()
	M.Place(ns.db.settings.minimapAngle or 215)
	M.Refresh()
	M.UpdateBadge()
end)
ns.On("LM_MINIMAP_CHANGED", M.Refresh)
