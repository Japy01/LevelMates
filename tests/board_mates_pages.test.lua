STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, C = ns.Board, ns.Comm
-- 25 guildmates online: the Mates tab pages them, none is left out
for i = 1, 25 do
	local n = "Mate" .. string.char(64 + i)
	STUB.guildMembers[n] = true
	STUB.Receive("LVLM2", C.Encode("hb", { l = 20, z = 1412, c = "MAGE" }), "GUILD", n .. "-Testrealm")
end
B.Toggle(); B.ShowTab("mates")
local function names() local out = {}; for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.mate then out[#out + 1] = r.button.mate end end; return out end
local seen = {}
for _, n in ipairs(names()) do seen[n] = true end
assert(#names() == 20 and B.journalNext:IsShown(), "a first page and the pager")
B.TurnPage(1)
for _, n in ipairs(names()) do seen[n] = true end
local count = 0; for n in pairs(seen) do if n:find("^Mate") then count = count + 1 end end
assert(count == 25, "all 25 across the pages: " .. count)
-- a help request still shows, above the pager
STUB.Receive("LVLM2", C.Encode("help", { t = "Ogro", z = 1412, x = 40, y = 50, id = "h0000009" }), "GUILD", "MateA-Testrealm")
B.Refresh()
local helpShown = false
for _, hr in ipairs(B.helpRows) do if hr.text:IsShown() then helpShown = true end end
assert(helpShown and B.journalNext:IsShown() and not B.helpRows[1].text:IsShown(), "help above the pager")
