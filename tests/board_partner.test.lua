STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, P, L = ns.Comm, ns.Board, ns.Partner, ns.L
STUB.player.level = 20; STUB.player.mapId = 1421
local function mate(name, level, z) STUB.Receive("LVLM", C.Encode("hb", { l = level, z = z }), "GUILD", name .. "-Testrealm") end
local function pal(name) STUB.Receive("LVLM", C.Encode("pal", { p = 1 }), "GUILD", name .. "-Testrealm") end
mate("Alto", 40, 1421); mate("Lejos", 22, 1412); mate("Cerca", 19, 1421); mate("Solo", 21, 1421); mate("Marcado", 30, 1421)
pal("Lejos"); pal("Cerca"); pal("Marcado")
B.Toggle()
local function shown()
	local out = {}
	for i = 1, #B.rows do local r = B.rows[i]; if r.button:IsShown() then out[#out + 1] = r.name.text end end
	return table.concat(out, ",")
end
local function rowOf(name) for i = 1, #B.rows do if B.rows[i].name.text == name then return B.rows[i] end end end
local function same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] end

assert(B.palCheck and B.palCheck:IsShown() and not B.palCheck:GetChecked(), "check box on the guildmates tab, unticked")
assert(shown() == "Alto,Marcado,Lejos,Solo,Cerca", "not looking: the usual order: " .. shown())
B.palCheck:SetChecked(true); B.palCheck.scripts.OnClick(B.palCheck)
assert(P.IsOn(), "the check box turns it on")
assert(shown() == "Cerca,Lejos,Alto,Marcado,Solo", "matches first, my zone first, then the usual order: " .. shown())
assert(same(rowOf("Cerca").bg.colorTexture, B.PAL_TINT) and same(rowOf("Lejos").bg.colorTexture, B.PAL_TINT), "matches are tinted")
assert(not same(rowOf("Marcado").bg.colorTexture, B.PAL_TINT), "marked but 10 levels away: not tinted")

-- tooltip only on matches
local cerca = rowOf("Cerca")
cerca.button.scripts.OnEnter(cerca.button)
assert(GameTooltip.lines[1] == L.PAL_TOOLTIP and not GameTooltip.hidden, "tooltip on a match")
cerca.button.scripts.OnLeave(cerca.button)
local alto = rowOf("Alto")
alto.button.scripts.OnEnter(alto.button)
assert(GameTooltip.hidden, "no tooltip on a non-match")

-- the near-level filter and the search still apply
B.nearCheck:SetChecked(true); B.nearCheck.scripts.OnClick(B.nearCheck)
assert(shown() == "Cerca,Lejos,Solo", "near filter first, then matches on top: " .. shown())
B.nearCheck:SetChecked(false); B.nearCheck.scripts.OnClick(B.nearCheck)
B.searchBox:SetText("lej"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "Lejos", "search still filters")
B.searchBox:SetText(""); B.searchBox.scripts.OnTextChanged(B.searchBox)

-- the box and both labels belong to the guildmates tab
B.tabs.lfg.scripts.OnClick(B.tabs.lfg)
assert(not B.palCheck:IsShown() and not B.palLabel:IsShown() and not B.nearLabel:IsShown(), "hidden on the Dungeons tab")
B.tabs.mates.scripts.OnClick(B.tabs.mates)
assert(B.palCheck:IsShown() and B.palLabel:IsShown() and B.nearLabel:IsShown() and B.palCheck:GetChecked(), "back, still ticked")

-- unticking restores the usual order
B.palCheck:SetChecked(false); B.palCheck.scripts.OnClick(B.palCheck)
assert(not P.IsOn() and shown() == "Alto,Marcado,Lejos,Solo,Cerca", "off: usual order again: " .. shown())
assert(not same(rowOf("Cerca").bg.colorTexture, B.PAL_TINT), "tint removed")

-- a refused tick (sharing off) re-syncs the box
ns.db.settings.share = false; C.Stop()
B.Toggle(); B.Toggle()
B.palCheck:SetChecked(true); B.palCheck.scripts.OnClick(B.palCheck)
assert(not P.IsOn() and not B.palCheck:GetChecked(), "box unticked again when refused")
-- header layout: the box clears the divider and the subtitle stops before the box
local pt = B.palCheck.point
local boxLeft = B.WIDTH + pt[2] - B.palCheck:GetWidth()
assert(-pt[3] + B.palCheck:GetHeight() <= B.TOP - 8, "box ends above the divider")
assert(B.subtitle:GetWidth() > 0 and B.MARGIN + B.subtitle:GetWidth() <= boxLeft - 4, "subtitle is capped before the box")
