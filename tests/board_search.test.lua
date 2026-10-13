-- Board header and search: heading + subtitle, a search box that filters by name.
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, B, L = ns.Comm, ns.Board, ns.L
for _, n in ipairs({ { "Mario", 30 }, { "Ana", 12 }, { "Marta", 22 } }) do
	STUB.Receive("LVLM2", C.Encode("hb", { l = n[2], z = 1421 }), "GUILD", n[1] .. "-Testrealm")
end
B.Toggle(); B.ShowTab("mates")   -- the board opens on Home; this test is about Guildmates
local function shown()
	local out = {}
	for i = 1, #B.rows do local r = B.rows[i]; if r.button:IsShown() and r.button.mate ~= ns.Me() then out[#out + 1] = r.name.text end end
	return table.concat(out, ",")
end
assert(B.heading.text == L.BOARD_HEADING and B.subtitle.text == L.BOARD_SUBTITLE, "heading and subtitle")
assert(shown() == "Mario,Marta,Ana", "all by default: " .. shown())
B.searchBox:SetText("mar"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "Mario,Marta", "search is case-insensitive and matches inside names: " .. shown())
B.searchBox:SetText("Marta"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "Marta", "narrowed: " .. shown())
B.searchBox:SetText("zzz"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "" and B.frame.empty.text == L.EMPTY_FILTERED, "nothing matches: " .. tostring(B.frame.empty.text))
B.searchBox:SetText(""); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "Mario,Marta,Ana", "cleared")
-- the search text is not a pattern: characters like % or . are plain
B.searchBox:SetText("%"); B.searchBox.scripts.OnTextChanged(B.searchBox)
assert(shown() == "", "'%' does not blow up or match everything")
