-- TalentView.lua: a guildmate's build drawn on their class tree, our own window, laid out as the game's: the branches
-- side by side, each its own panel (the class's art, a round icon, its name and points), the talents on a grid in it
-- (Talents.Grid), arrows between them. The game's own node art says each talent's state: yellow full, green partial,
-- gray open (could be taken), dark locked (Talents.States); choice nodes as such. The spell's tooltip on each.
-- The tree comes from Talents.lua (ours, or a guildmate's of that class); without it, the guild is asked and the
-- game's own link stays on offer. Nothing here opens or touches the game's talent window.
local _, ns = ...
local TV = {}
ns.TalentView = TV
local L, TL, SK = ns.L, ns.Talents, ns.Skin

local NODE = 36                    -- a talent's icon
local CELL_X, CELL_Y = 56, 52      -- the grid
local HEAD = 64                    -- a branch's head
local PAD_X = 22                   -- a branch's side margins
local TOP, FOOT, SIDE = 30, 48, 12 -- the window around the branches
local MIN_COLS = 4                 -- a narrow branch still gets a fair panel

local function atlasOr(tex, atlas, r, g, b, a)
	if SK.HasAtlas(atlas) then tex:SetAtlas(atlas) else tex:SetColorTexture(r, g, b, a or 0.9) end
end
local function classColor(class)
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class or ""]
	if c then return c.r, c.g, c.b end
	return 0.6, 0.6, 0.6
end

local function build()
	local f = SK.Window("LevelMatesTalentView", UIParent)
	f:SetSize(760, 560); f:SetPoint("CENTER"); f:SetFrameStrata("HIGH"); if f.SetToplevel then f:SetToplevel(true) end
	f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.SetClampedToScreen then f:SetClampedToScreen(true) end
	f:Hide()
	if UISpecialFrames then table.insert(UISpecialFrames, "LevelMatesTalentView") end   -- Escape closes it
	TV.frame = f
	TV.title = f.TitleText
	TV.body = CreateFrame("Frame", nil, f)
	TV.body:SetPoint("TOPLEFT", SIDE, -TOP)
	TV.bodyBg = TV.body:CreateTexture(nil, "BACKGROUND"); TV.bodyBg:SetAllPoints(); TV.bodyBg:SetColorTexture(0.03, 0.03, 0.03, 1)
	TV.lineLayer = CreateFrame("Frame", nil, TV.body)   -- arrows over the panels, under the talents
	TV.lineLayer:SetAllPoints(TV.body)
	TV.lineLayer:SetFrameLevel(TV.body:GetFrameLevel() + 3)
	TV.total = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	TV.total:SetPoint("BOTTOMLEFT", 18, 20); TV.total.lmKeep = true
	TV.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	TV.note:SetPoint("CENTER", TV.body, "CENTER", 0, 0); TV.note:SetWidth(460); TV.note:SetJustifyH("CENTER"); TV.note:SetWordWrap(true)
	TV.note.lmKeep = true
	TV.gameButton = SK.Button(f)
	TV.gameButton:SetSize(220, 22); TV.gameButton:SetPoint("BOTTOMRIGHT", -16, 14); TV.gameButton:SetText(L.TV_GAME)
	TV.gameButton:SetScript("OnClick", function() if TV.entry then ns.Builds.Open(TV.entry) end end)   -- the game's link, in my chat, to click
	TV.heads, TV.nodes, TV.lines = {}, {}, {}
end

-- A branch's panel: the class's art darkened, a line under the head, a round icon, its name, its points.
local function panel(i)
	local h = TV.heads[i]
	if h then return h end
	h = CreateFrame("Frame", nil, TV.body)
	h.art = h:CreateTexture(nil, "BACKGROUND", nil, 1); h.art:SetAllPoints()
	h.shade = h:CreateTexture(nil, "BACKGROUND", nil, 2); h.shade:SetAllPoints(); h.shade:SetColorTexture(0, 0, 0, 0.45)
	h.divider = h:CreateTexture(nil, "BORDER"); h.divider:SetWidth(1)
	h.divider:SetPoint("TOPRIGHT"); h.divider:SetPoint("BOTTOMRIGHT"); h.divider:SetColorTexture(0.45, 0.36, 0.2, 0.8)
	h.rule = h:CreateTexture(nil, "ARTWORK"); h.rule:SetHeight(1)
	h.rule:SetPoint("TOPLEFT", 14, -HEAD + 8); h.rule:SetPoint("TOPRIGHT", -14, -HEAD + 8); h.rule:SetColorTexture(0.8, 0.64, 0.3, 0.45)
	h.icon = h:CreateTexture(nil, "ARTWORK"); h.icon:SetSize(34, 34); h.icon:SetPoint("TOPLEFT", 16, -12)
	if h.icon.SetMask then pcall(h.icon.SetMask, h.icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end   -- round
	h.ring = h:CreateTexture(nil, "OVERLAY"); h.ring:SetSize(56, 56); h.ring:SetPoint("TOPLEFT", h.icon, "TOPLEFT", -5, 5)
	h.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")   -- the game's round frame
	h.name = h:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); h.name:SetPoint("LEFT", h.icon, "RIGHT", 12, 6)
	h.points = h:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); h.points:SetPoint("TOPLEFT", h.name, "BOTTOMLEFT", 0, -2)
	h.name.lmKeep, h.points.lmKeep = true, true   -- light writing on the dark art
	TV.heads[i] = h
	return h
end

local function nodeButton(i)
	local b = TV.nodes[i]
	if b then return b end
	b = CreateFrame("Button", nil, TV.body)
	b:SetSize(NODE, NODE)
	b:SetFrameLevel(TV.body:GetFrameLevel() + 5)
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 3, -3); b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.ring = b:CreateTexture(nil, "OVERLAY"); b.ring:SetPoint("TOPLEFT", -7, 7); b.ring:SetPoint("BOTTOMRIGHT", 7, -7)
	b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); b.rank:SetPoint("BOTTOMRIGHT", 5, -5)
	b.rank.lmKeep = true
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.spell and self.spell > 0 and GameTooltip.SetSpellByID then pcall(GameTooltip.SetSpellByID, GameTooltip, self.spell) end
		GameTooltip:AddLine(self.stateText, 1, 0.82, 0)
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
	TV.total:SetText("")
end

local function say(text)
	clear()
	TV.frame:SetSize(560, 300); TV.body:SetSize(560 - 2 * SIDE, 300 - TOP - FOOT)
	TV.note:SetText(text); TV.note:Show()
end

-- each state: its art (square or choice), its fallback colour, how the icon looks
local LOOK = {
	max = { art = "yellow", r = 1, g = 0.82, b = 0, alpha = 1 },
	partial = { art = "green", r = 0.3, g = 0.9, b = 0.35, alpha = 1 },
	open = { art = "gray", r = 0.45, g = 0.44, b = 0.4, alpha = 0.75, faded = true },
	locked = { art = "locked", r = 0.22, g = 0.21, b = 0.19, alpha = 0.4, faded = true },
}

local function draw(e, plan, got)
	TV.note:Hide()
	clear()
	local grid = TL.Grid(plan)
	if not grid then return say(L.TV_BAD) end
	local states = TL.States(plan, grid, got)
	local cr, cg, cb = classColor(e.c)
	local class = e.c and e.c:lower()
	local art = class and "talent-background-" .. class
	local treeH = HEAD + grid.rows * CELL_Y + 14
	-- the panels, left to right; where each branch's first column starts
	local x, origin = 0, {}
	for i, t in ipairs(grid.trees) do
		local cols = math.max(MIN_COLS, t.cols)
		local w = cols * CELL_X + 2 * PAD_X
		local h = panel(i)
		h:ClearAllPoints(); h:SetPoint("TOPLEFT", TV.body, "TOPLEFT", x, 0); h:SetSize(w, treeH)
		if art and SK.HasAtlas(art) then h.art:SetAtlas(art) else h.art:SetColorTexture(cr * 0.18, cg * 0.18, cb * 0.18, 1) end
		local g = plan.groups[i]
		h.icon:SetTexture(TL.BranchIcon(e.c, g, i))
		h.name:SetText(TL.BranchName(e.c, g, i))
		h.points:SetText(tostring(got.points[t.group] or 0))
		h.divider:SetShown(i < #grid.trees)
		h:Show()
		origin[i] = x + PAD_X + (cols - t.cols) * CELL_X / 2 + (CELL_X - NODE) / 2   -- a narrow branch, centred
		x = x + w
	end
	TV.body:SetSize(x, treeH)
	TV.frame:SetSize(x + 2 * SIDE, TOP + treeH + FOOT)
	local function place(id)
		local c = grid.cells[id]
		return origin[c.tree] + (c.col - 1) * CELL_X + NODE / 2, -(HEAD + (c.row - 1) * CELL_Y + NODE / 2)
	end
	-- the arrows, centre to centre under the talents, lit when their source is full
	local li = 0
	if TV.lineLayer.CreateLine then
		for _, n in ipairs(plan.nodes) do
			for _, t in ipairs(n.to or {}) do
				if grid.cells[n.id] and grid.cells[t] then
					li = li + 1
					local l = TV.lines[li] or TV.lineLayer:CreateLine(nil, "ARTWORK")
					TV.lines[li] = l
					l:SetThickness(2)
					local x1, y1 = place(n.id)
					local x2, y2 = place(t)
					l:SetStartPoint("TOPLEFT", TV.body, x1, y1); l:SetEndPoint("TOPLEFT", TV.body, x2, y2)
					if states[n.id] == "max" then l:SetColorTexture(1, 0.82, 0, 0.95) else l:SetColorTexture(0.35, 0.33, 0.3, 0.8) end
					l:Show()
				end
			end
		end
	end
	-- the talents
	local i, total = 0, 0
	for _, n in ipairs(plan.nodes) do
		if grid.cells[n.id] then
			i = i + 1
			local b = nodeButton(i)
			local pick = got.nodes[n.id]
			local state = states[n.id] or "locked"
			local look = LOOK[state]
			b.nodeId, b.state = n.id, state
			b.px, b.py = place(n.id)
			b:ClearAllPoints(); b:SetPoint("CENTER", TV.body, "TOPLEFT", b.px, b.py)
			b.spell = n.spells[pick and pick.entry or 1] or n.spells[1]
			b.icon:SetTexture(spellIcon(b.spell))
			b.icon:SetDesaturated(look.faded and true or false); b.icon:SetAlpha(look.alpha)
			atlasOr(b.ring, "talents-node-" .. (n.type == 2 and "choice" or "square") .. "-" .. look.art, look.r, look.g, look.b)
			local rank = pick and (pick.granted and n.max or pick.rank) or 0
			b.rank:SetText(rank .. "/" .. n.max)
			b.stateText = pick and pick.granted and L.TV_GRANTED or (rank == 0 and L.TV_NOT_TAKEN or string.format(L.TV_RANK, rank, n.max))
			if pick and not pick.granted then total = total + rank end
			b:Show()
		end
	end
	TV.total:SetText(string.format(L.TV_TOTAL, total))
end

local function refresh()
	local e = TV.entry
	if not (e and TV.frame and TV.frame:IsShown()) then return end
	TV.title:SetText(string.format(L.TV_TITLE, e.name or "?", e.l or 0))
	TV.gameButton:Show()
	local plan = TL.LayoutOf(e.c)
	if not plan then TL.Ask(e.c); return say(L.TV_WAITING) end
	local got, why = TL.Decode(e.b, plan)
	if not got then
		if why == "tree" then TL.Ask(e.c, TL.HashOf(e.b)); return say(L.TV_OTHER_TREE) end
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
