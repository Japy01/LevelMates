-- The dark theme (asked 2026-10-19, like the game's dungeon journal): a near-black page, text as the game paints
-- it (no ink), light thin lines and bands; the default. Parchment stays as an option (ink, brown bands); a change
-- asks for a reload
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local SK, B, L, S, W = ns.Skin, ns.Board, ns.L, ns.Settings, ns.Widgets
assert(ns.db.settings.theme == "dark" and SK.Dark(), "dark by default")
local r, g, b = SK.Ink(0.67, 0.83, 0.45)
assert(math.abs(r - 0.67) < 1e-6 and math.abs(g - 0.83) < 1e-6 and math.abs(b - 0.45) < 1e-6, "no ink on a dark page: colours stay")
assert(SK.InkText("|cffa335eex|r") == "|cffa335eex|r", "colour codes untouched")
assert(SK.C.section[4] <= 0.12 and SK.C.section[1] >= 0.9 and SK.C.line[1] >= 0.9, "light translucent bands and lines on the dark page")
B.Toggle()
assert(B.TOP < 120, "no parchment curl to clear: the heading sits high: " .. B.TOP)
local page = B.frame.page
assert(page and page.atlas == nil and page.colorTexture and page.colorTexture[1] < 0.12 and page.colorTexture[4] >= 0.9, "the page: a near-black colour, no parchment art")
-- a panel's band and the row highlight follow the theme
local p = W.Panel(B.frame, "x")
assert(p.band.colorTexture[1] >= 0.9 and p.band.colorTexture[4] <= 0.12, "panel band light and faint: " .. tostring(p.band.colorTexture[1]))
assert(B.rows[1].button.highlight and B.rows[1].button.highlight.colorTexture[1] >= 0.9, "a light highlight on dark rows")
-- the option: parchment, with a reload offered
local theme
for _, st in ipairs(S.AllSettings()) do if st.name == L.OPT_THEME then theme = st end end
assert(theme and theme.dropdown, "a theme dropdown in Options")
STUB.popups = STUB.popups or {}
theme:SetValue("parchment")
assert(ns.db.settings.theme == "parchment", "parchment chosen")
SK.ApplyTheme()
assert(not SK.Dark() and SK.C.section[1] < 0.5, "parchment colours back after the theme applies")
r, g, b = SK.Ink(1, 1, 1)
assert(r < 0.5, "ink again on parchment")
print("ok")
