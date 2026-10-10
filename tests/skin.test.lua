STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, SK, L = ns.Board, ns.Skin, ns.L
assert(ns.db.settings.style == "gold" and SK.On(), "LevelMates' own style by default")
B.Toggle()
local f = B.frame
assert(f.template == "BackdropTemplate" and f.backdropColor and f.backdropColor[1] == SK.C.frame[1], "a brown window")
assert(f.Inset and f.Inset.colorTexture[1] == SK.C.panel[1], "a lighter inner panel, drawn under the window's texts")
assert(f.TitleText.text == B.TitleString(), "its title")
assert(B.helpButton.template == "BackdropTemplate" and B.helpButton.backdropBorder[1] == SK.C.buttonBorder[1], "gold-bordered buttons")
assert(B.tabs.mates.template == "BackdropTemplate" and B.tabs.mates.enabled == false and B.tabs.lfg.enabled ~= false, "flat tabs, the active one marked")
assert(B.tabs.mates.backdropColor[1] == SK.C.tabActive[1] and B.tabs.lfg.backdropColor[1] == SK.C.tab[1], "the active tab is lighter")
B.ShowTab("lfg")
local card = B.cards[1]
assert(card.skin and card.art.point and card.top and card.bottom, "cards: the picture fills them, bands for the text")
local fits, far
for _, c in ipairs(B.cards) do if c.fits then fits = c else far = c end end
assert(fits.backdropBorder[1] == SK.C.card[1] and far.backdropBorder[1] == SK.C.cardDim[1], "gold border for my level, dim for the rest")
assert(far.levels.text:find(string.format(L.CARD_LEVELS, ns.Dungeons.Get(far.dungeonId).min, ns.Dungeons.Get(far.dungeonId).max), 1, true), "levels")
-- the other windows share it
ns.MateCard.Show("Nadie")
assert(ns.MateCard.frame.template == "BackdropTemplate" and ns.MateCard.whisper.template == "BackdropTemplate", "the card too")
-- the classic option gives back the game's frames (after a reload)
ns.db.settings.style = "classic"
assert(not SK.On() and SK.Button(UIParent).template == "UIPanelButtonTemplate" and SK.Window("X").template == "BasicFrameTemplateWithInset", "classic")
