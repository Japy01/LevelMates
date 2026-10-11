STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, HM, L = ns.Comm, ns.Home, ns.L
local function kinds(rows) local out = {}; for _, r in ipairs(rows) do out[#out + 1] = r.header and ("#" .. r.header) or r.kind end; return table.concat(out, ",") end

-- nobody around: the guild block and the invite, nothing else
local rows = HM.Rows()
assert(kinds(rows) == "#guild,level,challenge,invite", "alone: " .. kinds(rows))
assert(HM.InviteText():find("LevelMates", 1, true), "an invite to copy")

-- guildmates: near my level or in my zone, help, groups, meetups today, gifts I wish for, trainer
STUB.items[2589] = "|cffffffff|Hitem:2589::::::::20:::::::|h[Linen Cloth]|h|r"
STUB.Receive("LVLM", C.Encode("hb", { l = 22, z = 1500, c = "MAGE" }), "GUILD", "Mario-Testrealm")    -- near my level (20)
STUB.Receive("LVLM", C.Encode("hb", { l = 40, z = 1412, c = "PRIEST" }), "GUILD", "Ana-Testrealm")    -- my zone
STUB.Receive("LVLM", C.Encode("hb", { l = 50, z = 1600 }), "GUILD", "Luis-Testrealm")                 -- neither
STUB.Receive("LVLM", C.Encode("help", { t = "Ogro", z = 1412, x = 40, y = 50, id = "h0000001" }), "GUILD", "Ana-Testrealm")
STUB.Receive("LVLM", C.Encode("lfg", { d = 5, r = "H", id = "lfg00001", m = 20 }), "GUILD", "Mario-Testrealm")
ns.Meetups.AddSample("Mario", 6, 30, {})
ns.Wishlist.Add(STUB.items[2589])
STUB.Receive("LVLM", C.Encode("gv", { ids = "2589" }), "GUILD", "Luis-Testrealm")
ns.char.trainer = { seen = true, spells = { { name = "Blink", level = 20 } } }
ns.Trainer.LevelUp(20)
rows = HM.Rows()
local k = kinds(rows)
assert(k:find("#now,help,lfg,meet", 1, true), "now: help, a group, today's meetup: " .. k)
assert(k:find("#foryou,mate,mate,gift,trainer", 1, true), "for you: two mates, a gift, the trainer: " .. k)
assert(not k:find("invite", 1, true), "no invite once there are guildmates")
local mates = {}
for _, r in ipairs(rows) do if r.kind == "mate" then mates[#mates + 1] = r.name end end
table.sort(mates)
assert(table.concat(mates, ",") == "Ana,Mario", "Luis is neither near nor here")
for _, r in ipairs(rows) do if r.kind == "trainer" then assert(r.n == 1 and r.names:find("Blink", 1, true), "the spells waiting") end end
for _, r in ipairs(rows) do if r.header == "now" then assert(r.count == 3, "counted") end end

-- the trainer row goes once I visit a trainer
ns.Trainer.Record = ns.Trainer.Record   -- (kept)
STUB.Fire("TRAINER_SHOW"); STUB.Advance(0.1)
assert(not kinds(HM.Rows()):find("trainer", 1, true), "visited: gone")

-- this week's rankings
ns.Points.AddSample("Mario", { t = 40, l = 3, d = 1, h = 0, q = 5 })
rows = HM.Rows()
k = kinds(rows)
assert(k:find("#week,rank", 1, true), "this week: " .. k)
for _, r in ipairs(rows) do if r.kind == "rank" and r.cat == "l" then assert(r.top[1].name == "Mario", "levels top") end end
