STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local RP, C, L = ns.Report, ns.Comm, ns.L
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, v = "0.3.0" }), "GUILD", "Mario-Testrealm")
ns.db.settings.sharePos = true

-- the report: what is needed to understand a problem (guildmates counted by version, no names)
local text = RP.Text()
for _, want in ipairs({ "LevelMates", ns.VERSION, "1.60.1", "Test Guild", C.ActiveTransport(), "0.3.0 ×1", "sharePos" }) do
	assert(text:find(want, 1, true), "has " .. want .. ":\n" .. text)
end
assert(not text:find("Mario", 1, true), "no names")

-- LevelMates' own errors are kept (the last 5), and still reach the game's handler
for i = 1, 7 do
	local ev = "LM_TEST_ERR" .. i
	ns.On(ev, function() error("Core.lua:" .. i .. ": e") end)
	ns.Fire(ev)
end
local n = 0
for _ in RP.Text():gmatch("Core%.lua:%d+") do n = n + 1 end
assert(n == 5 and not RP.Text():find("Core.lua:1:", 1, true), "the last five")
assert(#STUB.handled >= 7, "every one still went to the game's handler")

-- /lm informe opens it in the copy box; nothing is sent
local sent = #STUB.sent
SlashCmdList.LEVELMATES("informe")
assert(ns.DiscordCopy.frame:IsShown() and ns.DiscordCopy.box.text:find(ns.VERSION, 1, true), "in the copy box")
assert(#STUB.sent == sent, "nothing sent")
