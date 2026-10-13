-- TalentView.lua: a guildmate's build drawn on their class tree, our own window: the three branches side by side as
-- the game lays them out (its node positions, scaled to fit), the game's own node art (yellow full, green partial,
-- gray not taken; choice nodes as such), arrows between nodes, each branch's points on top, the spell's tooltip.
-- The tree comes from Talents.lua (ours, or a guildmate's of that class); without it, the guild is asked and the
-- game's own link stays on offer. Nothing here opens or touches the game's talent window.
local _, ns = ...
local TV = {}
ns.TalentView = TV
local L, TL, SK = ns.L, ns.Talents, ns.Skin

local W, H = 820, 600              -- the window
local AREA_W, AREA_H = 760, 440    -- where the nodes go
local AREA_TOP = -110              -- below the title and the branch heads
local NODE = 34

local function atlasOr(tex, atlas, r, g, b)
	if SK.HasAtlas(atlas) then tex:SetAtlas(atlas) else tex:SetColorTexture(r, g, b, 0.9) end
end

local function build()
	local f = SK.Window("LevelMatesTalentView", UIParent)
	f:SetSize(W, H); f:SetPoint("CENTER"); f:SetFrameStrata("HIGH"); if f.SetToplevel then f:SetToplevel(true) end
	f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	if UISpecialFrames then table.insert(UISpecialFrames, "LevelMatesTalentView") end   -- Escape closes it
	TV.frame = f
	-- the class's own background art, under the nodes
	TV.bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	TV.bg:SetPoint("TOPLEFT", 8, -26); TV.bg:SetPoint("BOTTOMRIGHT", -8, 8)
	TV.title = f.TitleText
	TV.area = CreateFrame("Frame", nil, f)
	TV.area:SetSize(AREA_W, AREA_H); TV.area:SetPoint("TOP", 0, AREA_TOP)
	TV.heads = {}
	for i = 1, 3 do
		local h = CreateFrame("Frame", nil, f)
		h:SetSize(220, 44)
		h.icon = h:CreateTexture(nil, "ARTWORK"); h.icon:SetSize(28, 28); h.icon:SetPoint("LEFT", 0, 0)
		h.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		h.name = h:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); h.name:SetPoint("TOPLEFT", h.icon, "TOPRIGHT", 6, 0)
		h.points = h:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); h.points:SetPoint("TOPLEFT", h.name, "BOTTOMLEFT", 0, -2)
		h.name.lmKeep, h.points.lmKeep = true, true   -- light writing on the dark art
		TV.heads[i] = h
	end
	TV.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	TV.note:SetPoint("CENTER", 0, 10); TV.note:SetWidth(520); TV.note:SetJustifyH("CENTER"); TV.note:SetWordWrap(true)
	TV.note.lmKeep = true
	TV.gameButton = SK.Button(f)
	TV.gameButton:SetSize(220, 22); TV.gameButton:SetPoint("BOTTOM", 0, 16); TV.gameButton:SetText(L.TV_GAME)
	TV.gameButton:SetScript("OnClick", function() if TV.entry then ns.Builds.Open(TV.entry) end end)   -- the game's link, in my chat, to click
	TV.nodes, TV.lines = {}, {}
end

local function nodeButton(i)
	local b = TV.nodes[i]
	if b then return b end
	b = CreateFrame("Button", nil, TV.area)
	b:SetSize(NODE, NODE)
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 4, -4); b.icon:SetPoint("BOTTOMRIGHT", -4, 4)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.ring = b:CreateTexture(nil, "OVERLAY"); b.ring:SetPoint("TOPLEFT", -6, 6); b.ring:SetPoint("BOTTOMRIGHT", 6, -6)
	b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); b.rank:SetPoint("BOTTOMRIGHT", 6, -6)
	b.rank.lmKeep = true
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.spell and self.spell > 0 and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(self.spell) end
		GameTooltip:AddLine(self.state, 1, 0.82, 0)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	TV.nodes[i] = b
	return b
end

local function spellIcon(spell)
	return spell and spell > 0 and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell) or 134400   -- the question mark
end

local function clear()
	for _, b in ipairs(TV.nodes) do b:Hide() end
	for _, l in ipairs(TV.lines) do l:Hide() end
	for _, h in ipairs(TV.heads) do h:Hide() end
end

local function say(text)
	clear()
	TV.note:SetText(text); TV.note:Show()
end

-- Draw the build on the plan. The game's coordinates (posX right, posY down) are scaled to fit the area as a whole,
-- so the branches keep their places side by side.
local function draw(e, plan, got)
	TV.note:Hide()
	local known = {}
	for _, g in ipairs(plan.groups) do known[g.id] = true end
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	local nodes = {}
	for _, n in ipairs(plan.nodes) do
		if known[n.group] then
			nodes[#nodes + 1] = n
			minX, maxX = math.min(minX, n.x), math.max(maxX, n.x)
			minY, maxY = math.min(minY, n.y), math.max(maxY, n.y)
		end
	end
	local spanX, spanY = math.max(1, maxX - minX), math.max(1, maxY - minY)
	local scale = math.min((AREA_W - NODE) / spanX, (AREA_H - NODE) / spanY)
	local offX = (AREA_W - spanX * scale) / 2   -- centred
	local at = {}
	for i, n in ipairs(nodes) do
		local b = nodeButton(i)
		local pick = got.nodes[n.id]
		b.nodeId = n.id
		b.px = offX + (n.x - minX) * scale
		b.py = -(NODE / 2 + (n.y - minY) * scale)
		b:ClearAllPoints(); b:SetPoint("CENTER", TV.area, "TOPLEFT", b.px, b.py)
		local entry = pick and pick.entry or 1
		b.spell = n.spells[entry] or n.spells[1]
		b.icon:SetTexture(spellIcon(b.spell))
		local shape = n.type == 2 and "choice" or "square"
		local rank = pick and pick.rank or 0
		if rank >= n.max then
			atlasOr(b.ring, "talents-node-" .. shape .. "-yellow", 1, 0.82, 0)
		elseif rank > 0 then
			atlasOr(b.ring, "talents-node-" .. shape .. "-green", 0.2, 0.9, 0.2)
		else
			atlasOr(b.ring, "talents-node-" .. shape .. "-gray", 0.4, 0.4, 0.4)
		end
		b.icon:SetDesaturated(rank == 0); b.icon:SetAlpha(rank == 0 and 0.6 or 1)
		b.rank:SetText(rank .. "/" .. n.max)
		b.state = pick and pick.granted and L.TV_GRANTED or (rank == 0 and L.TV_NOT_TAKEN or string.format(L.TV_RANK, rank, n.max))
		b:Show()
		at[n.id] = b
	end
	-- the arrows: a line from each node to the ones it leads to (where the client draws lines)
	local li = 0
	if TV.area.CreateLine then
		for _, n in ipairs(nodes) do
			for _, t in ipairs(n.to or {}) do
				local a, z = at[n.id], at[t]
				if a and z then
					li = li + 1
					local l = TV.lines[li] or TV.area:CreateLine(nil, "BORDER")
					TV.lines[li] = l
					l:SetThickness(3)
					local lit = got.nodes[n.id] and got.nodes[t]
					l:SetColorTexture(lit and 1 or 0.45, lit and 0.82 or 0.45, lit and 0 or 0.45, lit and 0.9 or 0.6)
					l:SetStartPoint("TOPLEFT", TV.area, a.px, a.py); l:SetEndPoint("TOPLEFT", TV.area, z.px, z.py)
					l:Show()
				end
			end
		end
	end
	-- each branch's head over its nodes: name, icon and points
	for i, g in ipairs(plan.groups) do
		local h = TV.heads[i]
		if h then
			local sum, count = 0, 0
			for _, n in ipairs(nodes) do if n.group == g.id then sum = sum + (offX + (n.x - minX) * scale); count = count + 1 end end
			local cx = count > 0 and sum / count or AREA_W * (i - 0.5) / 3
			h:ClearAllPoints(); h:SetPoint("TOP", TV.area, "TOPLEFT", cx + 20, 60)
			h.icon:SetTexture(g.icon and g.icon > 0 and g.icon or 134400)
			h.name:SetText(g.name or "")
			h.points:SetText(tostring(got.points[g.id] or 0))
			h:Show()
		end
	end
end

local function refresh()
	local e = TV.entry
	if not (e and TV.frame and TV.frame:IsShown()) then return end
	TV.title:SetText(string.format(L.TV_TITLE, e.name or "?", e.l or 0))
	local class = e.c and e.c:lower()
	if class and SK.HasAtlas("talent-background-" .. class) then TV.bg:SetAtlas("talent-background-" .. class) else TV.bg:SetColorTexture(0.05, 0.05, 0.07, 1) end
	TV.gameButton:Show()
	local plan = TL.LayoutOf(e.c)
	if not plan then TL.Ask(e.c); return say(L.TV_WAITING) end
	local got, why = TL.Decode(e.b, plan)
	if not got then
		if why == "tree" then
			TL.Ask(e.c, TL.HashOf(e.b))
			return say(L.TV_OTHER_TREE)
		end
		return say(L.TV_BAD)
	end
	draw(e, plan, got)
end

-- Open a build ({ name, c, s, l, b }): false when there is nothing to draw (no code).
function TV.Open(e)
	if not (e and e.b and e.c) then return false end
	if not TV.frame then build() end
	TV.entry = e
	TV.frame:Show(); if TV.frame.Raise then TV.frame:Raise() end
	refresh()
	return true
end

ns.On("LM_TALENT_LAYOUTS_CHANGED", function(class) if TV.entry and TV.entry.c == class then refresh() end end)
