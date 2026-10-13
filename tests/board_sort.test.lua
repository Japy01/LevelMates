-- Board: sort by level or zone from the column headers, "near my level (±5)" filter, both remembered per character.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B = ns.Comm, ns.Board
STUB.player.level = 20
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 12, z = 1412 }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM2", C.Encode("hb", { l = 22, z = 1421 }), "GUILD", "Luis-Testrealm")
B.Toggle(); B.ShowTab("mates")   -- the board opens on Home; this test is about Guildmates

local function shown()
	local out = {}
	for i = 1, #B.rows do local r = B.rows[i]; if r.button:IsShown() and r.button.mate ~= ns.Me() then out[#out + 1] = r.name.text end end
	return table.concat(out, ",")
end

assert(shown() == "Mario,Luis,Ana", "default: level, highest first: " .. shown())
B.headers.level.scripts.OnClick(B.headers.level)
assert(shown() == "Ana,Luis,Mario", "level header again: lowest first: " .. shown())
B.headers.level.scripts.OnClick(B.headers.level)
assert(shown() == "Mario,Luis,Ana", "and back: " .. shown())
B.headers.zone.scripts.OnClick(B.headers.zone)
assert(shown() == "Ana,Mario,Luis", "zone name, then level high to low: " .. shown())
-- near my level: |level - mine| <= 5
B.nearCheck:SetChecked(true); B.nearCheck.scripts.OnClick(B.nearCheck)
assert(shown() == "Luis", "only Luis within 5 levels of 20: " .. shown())
assert(ns.char.boardNear == true and ns.char.boardSort and ns.char.boardSort.mode == "zone", "choices saved on the character")
B.nearCheck:SetChecked(false); B.nearCheck.scripts.OnClick(B.nearCheck)
assert(shown() == "Ana,Mario,Luis", "filter off again: " .. shown())
-- the empty-list text distinguishes "nobody online" from "the filter hides everyone"
B.nearCheck:SetChecked(true); B.nearCheck.scripts.OnClick(B.nearCheck)
STUB.player.level = 60
B.Refresh()
assert(shown() == "" and B.frame.empty.text == ns.L.EMPTY_FILTERED, "filter hides all: " .. tostring(B.frame.empty.text))
