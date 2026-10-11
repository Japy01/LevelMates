STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local RP, C, L = ns.Report, ns.Comm, ns.L
STUB.Receive("LVLM", C.Encode("hb", { l = 24, z = 1421, v = "0.3.0" }), "GUILD", "Mario-Testrealm")
ns.db.settings.sharePos = true

-- the report: what is needed to understand a problem
local text = RP.Text()
for _, want in ipairs({ "LevelMates", ns.VERSION, "1.60.1", "Test Guild", C.ActiveTransport(), "Mario 0.3.0", "sharePos" }) do
	assert(text:find(want, 1, true), "has " .. want .. ":\n" .. text)
end

-- LevelMates' own errors are kept (the last 5); the previous handler still gets every error
geterrorhandler()("Interface/AddOns/LevelMates/Board.lua:12: attempt to index nil")
geterrorhandler()("Interface/AddOns/OtherAddon/x.lua:1: boom")
assert(#STUB.handled == 2, "every error still goes to the handler that was there")
text = RP.Text()
assert(text:find("Board.lua:12", 1, true) and not text:find("OtherAddon", 1, true), "only ours in the report")
for i = 1, 7 do geterrorhandler()("Interface/AddOns/LevelMates/Core.lua:" .. i .. ": e") end
local n = 0
for _ in text.gsub(RP.Text(), "Core%.lua:%d+", "") and RP.Text():gmatch("Core%.lua:%d+") do n = n + 1 end
assert(n == 5 and not RP.Text():find("Board.lua:12", 1, true), "the last five")

-- /lm informe opens it in the copy box; nothing is sent
local sent = #STUB.sent
SlashCmdList.LEVELMATES("informe")
assert(ns.DiscordCopy.frame:IsShown() and ns.DiscordCopy.box.text:find(ns.VERSION, 1, true), "in the copy box")
assert(#STUB.sent == sent, "nothing sent")
