STUB.atlases["spellbook-Page-Right-C60"] = true
STUB.atlases["spellbook-background-evergreen-ribbon"] = true
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, SK, L = ns.Board, ns.Skin, ns.L
assert(SK.On(), "one style")
B.Toggle()
local f = B.frame
assert(f.template == "ButtonFrameTemplate" or f.template == "BackdropTemplate", "the game's own frame (or a plain one)")
local page = (f.Inset and f.Inset.page) or f.page
assert(page and page.atlas == SK.PAGE and f.Ribbon and f.Ribbon.atlas == SK.RIBBON, "a parchment page with the spellbook's ribbon")
assert(B.divider.atlas == SK.DIVIDER and B.colStrip, "the spellbook's divider, a band for the columns")
assert(B.rows[1].stripe and B.rows[1].name.inked and B.heading.inked, "row lines; texts in ink")
local r, g, b = SK.Ink(1, 1, 1)
B.rows[1].name:SetTextColor(1, 1, 1)
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
assert(not cardPage, "small windows keep the game's dark panel")
