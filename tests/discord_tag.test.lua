-- the bot tag: when the option is on, every Discord line starts with [LM1 ...] (key=value, no spaces in values), the
-- human text after it; the whole line at most 236 bytes; off: the line as before
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local DC, A, L, M = ns.Discord, ns.Activities, ns.L, ns.Meetups
local function fields(line)
	local tag = line:match("^%[LM1 ([^%]]*)%]")
	if not tag then return nil end
	local out = {}
	for k, v in tag:gmatch("(%w+)=(%S+)") do out[k] = v end
	return out
end
local run = { id = "a1b2c3d4", d = 101, at = 29333333, by = "Santo Fiämbre", role = "T", size = 40, caps = A.Caps(101), joined = {}, n = "traed pociones" }

assert(ns.db.settings.discordTag == false, "off by default")
assert(not DC.Line("new", run):find("[LM1", 1, true), "off: no tag")
ns.db.settings.discordTag = true
local line = DC.Line("new", run)
local f = fields(line)
assert(f, "the tag first: " .. line)
assert(f.id == "a1b2c3d4" and f.ev == "new" and f.act == "101" and f.at == "29333333", "id, event, activity, when")
assert(f.by == "Santo_Fiämbre" and f.lr == "T", "the leader (spaces as _) and their role")
assert(f.s == "T1/5,H0/10,D0/25", "places after the event: " .. tostring(f.s))
assert(line:find("[LevelMates]", 1, true), "the human text follows")
-- a join: who and their role, places counted with them
local j = fields(DC.Line("join", run, "Ana Bel", "H"))
assert(j.ev == "join" and j.who == "Ana_Bel" and j.wr == "H" and j.s == "T1/5,H1/10,D0/25", "a join: " .. tostring(j.s))
-- a Now group: no time, src=now; a free name travels
local now = { id = "ad000001", d = 190, t = "Jefe de mundo: Azuregos", by = "Mario", role = "H", size = 20, caps = A.Caps(190, 20), joined = {}, now = true }
local nf = fields(DC.Line("new", now))
assert(nf.src == "now" and nf.at == nil and nf.n == "Jefe_de_mundo:_Azuregos", "Now, with its name: " .. tostring(nf.n))
-- no roles: one count
local av = fields(DC.Line("new", { id = "av000001", d = 203, at = 29333400, by = "Mario", role = "A", size = 40, caps = A.Caps(203), joined = {} }))
assert(av.s == "A1/40", "no roles: " .. tostring(av.s))
-- cancel: the tag too
assert(fields(DC.Line("cancel", run)).ev == "cancel", "cancel tagged")
-- long names and notes: at most 236 bytes, the tag whole
local long = { id = "a1b2c3d4", d = 190, t = string.rep("Ñ", 40), at = 29333333, by = string.rep("Ñ", 12), role = "D", size = 40, caps = A.Caps(190, 40), joined = {}, n = string.rep("x", 40) }
local ll = DC.Line("join", long, string.rep("Ö", 12), "H")
assert(#ll <= 236 and fields(ll) and fields(ll).s, "at most 236 bytes, the tag whole: " .. #ll)
-- names never break the tag
local odd = fields(DC.Line("join", run, "Pe]pe=x", "D"))
assert(odd.who and not odd.who:find("[%]=]"), "no ] or = in a value")

-- Now groups in Discord: their joins, leaves and withdrawal go there too (the bot keeps the board right)
local posted = {}
SendChatMessage = function(text, chatType) if chatType == "GUILD_DISCORD" then posted[#posted + 1] = text end end
C_Discord = { IsEnabled = function() return true end, IsGuildChannelLinked = function() return true end, IsUserOAuthed = function() return true end }
local C = ns.Comm
STUB.Receive("LVLM2", C.Encode("hb", { l = 30, z = 1412, c = "MAGE" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("lfg", { d = 5, lr = "T", id = "mario001", m = 20, dc = 1 }), "GUILD", "Mario-Testrealm")
assert(ns.LFG.Join("mario001", "H"), "joined")
assert(posted[#posted] and fields(posted[#posted]).ev == "join" and fields(posted[#posted]).src == "now", "my join to a Now group in Discord")
assert(ns.LFG.Leave("mario001"), "left")
assert(fields(posted[#posted]).ev == "leave", "and my leave")
STUB.Advance(31)
assert(ns.LFG.Post{ d = 5, role = "T", discord = true }, "mine, in Discord")
local k, sentLfg
for i = #STUB.sent, 1, -1 do local kk, ff = C.Decode(STUB.sent[i].msg); if kk == "lfg" then sentLfg = ff; break end end
assert(sentLfg.dc == 2, "the ad says it is in Discord, with the tag (my switch is on)")
ns.LFG.Cancel()
assert(fields(posted[#posted]).ev == "cancel", "withdrawn: cancel in Discord")
