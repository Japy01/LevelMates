STUB.atlases["spellbook-Page-Right-C60"] = true
STUB.atlases["spellbook-background-evergreen-ribbon"] = true
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.char.groupsView = "catalog"   -- these checks are about the catalogue cards (the Groups section opens on Groups)
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, SK, L = ns.Board, ns.Skin, ns.L
assert(SK.On(), "one style")
B.Toggle()
local f = B.frame
assert(f.template == "ButtonFrameTemplate" or f.template == "BackdropTemplate", "the game's own frame (or a plain one)")
local page = f.page
assert(page and page.atlas == SK.PAGE and f.Ribbon and f.Ribbon.atlas == SK.RIBBON, "a parchment page with the spellbook's ribbon")
assert(B.divider.atlas == SK.DIVIDER and B.colStrip, "the spellbook's divider, a band for the columns")
assert(B.rows[1].stripe and B.rows[1].name.inked and B.heading.inked, "row lines; texts in ink")
local r, g, b = SK.Ink(1, 1, 1)
B.rows[1].name:SetTextColor(1, 1, 1); SK.InkPass()
assert(B.rows[1].name.color[1] == r and B.rows[1].name.color[3] == b, "white becomes dark ink")
ns.Professions.AddSample("Mario", { { id = 171, rank = 120 } })
B.ShowTab("crafts")
assert(B.rows[1].plaque:IsShown() and B.rows[1].button:GetHeight() == SK.HEAD_H and B.rows[2].button:GetHeight() == B.ROW_H and B.rows[2].plaque:IsShown() == false, "section bands on headers only")
B.ShowTab("mates")
assert((f.TitleContainer and f.TitleContainer.TitleText or f.TitleText).text == B.TitleString(), "its title")
assert(B.helpButton.template == "UIPanelButtonTemplate", "the game's red buttons")
assert(B.tabs.mates.skinTab and B.tabs.mates.enabled == false and B.tabs.mates.glow:IsShown() and not B.tabs.lfg.glow:IsShown(), "icon tabs, the active one lit")
B.ShowTab("lfg")
local fits, far
for _, c in ipairs(B.cards) do if c.fits then fits = c else far = c end end
assert(fits.backdropBorder[1] == SK.C.card[1] and far.backdropBorder[1] == SK.C.cardDim[1], "cards keep their gold or dim border")
ns.MateCard.Show("Nadie")
local cardPage = (ns.MateCard.frame.Inset and ns.MateCard.frame.Inset.page) or ns.MateCard.frame.page
assert(cardPage, "small windows have the page too")

-- /lm tinta: darker or lighter, live, from each text's own colour
B.ShowTab("mates")
local fs = B.heading
fs:SetTextColor(1, 1, 1); SK.InkPass()
local dark4 = fs.color[1]
SlashCmdList.LEVELMATES("tinta 1")
assert(ns.db.settings.ink == 1 and fs.color[1] > dark4, "lighter: " .. fs.color[1])
SlashCmdList.LEVELMATES("tinta 5")
assert(fs.color[1] < dark4, "darker")
SK.InkPass(); SK.InkPass()
assert(math.abs(fs.color[1] - SK.INK_LEVELS[5]) < 1e-6, "never darker twice")
SlashCmdList.LEVELMATES("tinta 9")
assert(ns.db.settings.ink == 5, "out of range: unchanged")

-- the guild banner in my faction's colours
UnitFactionGroup = function() return "Horde" end
assert(SK.Banner():find("INV_BannerPVP_01", 1, true), "red for the Horde")
UnitFactionGroup = function() return "Alliance" end
assert(SK.Banner():find("INV_BannerPVP_02", 1, true), "blue for the Alliance")

-- small windows: the page, and their writing in ink (the red buttons and typed text as said)
local SK = ns.Skin
local w = SK.Window("LevelMatesTestSmall", UIParent)
assert(w.page, "a small window has the page")
local label = w:CreateFontString(); label:SetTextColor(1, 0.82, 0)
local btn = SK.Button(w); local bfs = btn:CreateFontString(); bfs:SetTextColor(1, 0.82, 0)
local box = CreateFrame("EditBox", nil, w, "InputBoxTemplate"); box.kind = "EditBox"
w.scripts.OnShow(w)
local r = label:GetTextColor()
assert(r < 0.5, "the label in ink: " .. r)
assert(bfs:GetTextColor() == 1, "the button keeps its colour")
assert(box:GetTextColor() == 1, "typed text stays light on its dark box")
