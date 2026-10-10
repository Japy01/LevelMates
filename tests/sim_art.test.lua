STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
SlashCmdList["LEVELMATES"]("sim arte")
local f = _G.LevelMatesArtPreview
assert(f and f:IsShown(), "a preview window")
assert(#f.thumbs >= 20, "candidates shown: " .. #f.thumbs)
local seen = {}
for _, t in ipairs(f.thumbs) do assert(t.tex.texture ~= nil and t.label.text ~= "", "a texture with its label"); seen[t.label.text] = true end
assert(seen["7963776"] and seen["LoadScreenUldaman"], "file ids near Forever's and classic loading screens")
