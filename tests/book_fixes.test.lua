STUB.atlases["spellbook-Page-Right-C60"] = true
STUB.atlases["spellbook-background-evergreen-ribbon"] = true
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local B, SK, C, PT, L, R = ns.Board, ns.Skin, ns.Comm, ns.Points, ns.L, ns.Roster
local function last(kind) for i = #STUB.sent, 1, -1 do local k, f = C.Decode(STUB.sent[i].msg); if k == kind then return f end end end

-- C1: small windows have the parchment too, with their texts inked
ns.MateCard.Show("Nadie")
local mf = ns.MateCard.frame
assert(mf.page, "small windows have the page, their texts in ink")

-- I2: colour codes in a text (item links, quality colours) are written in ink too
B.Toggle()
local fs = B.rows[1].name
fs:SetText("|cffffffff|Hitem:2589|h[Linen Cloth]|h|r and |cff1eff00green|r"); ns.Skin.InkPass()
local r, g, b = SK.Ink(1, 1, 1)
local hex = string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
assert(fs.text:find("|cff" .. hex .. "|Hitem:2589", 1, true), "a white item link turns to ink: " .. fs.text)
assert(not fs.text:find("|cff1eff00", 1, true), "green too")

-- I3: texts on the page are inked, the ones on the dark bar are not
assert(not B.nearLabel.inked, "'near my level' sits on the dark bar")
for _, label in ipairs(B.recruitLabels) do assert(label.inked, "recruit labels on the page") end

-- I4: the icon tabs sit in the top band, under the title bar; the search clears the close button
local tp = B.tabs.home.point
assert(tp[5] == -24, "tabs at y -24: " .. tostring(tp[5]))
assert(B.searchBox.point[4] <= -30, "search left of the close button")

-- I5: the same dungeon counts once in three hours (a corpse run back in is not a new one)
local t0 = PT.Mine().t
ns.Journal.Add("dungeon", { name = "Deadmines", mates = { "Mario" } })
ns.Journal.Add("dungeon", { name = "Deadmines", mates = { "Mario" } })
assert(PT.Mine().t == t0 + 15, "counted once")
ns.Journal.Add("dungeon", { name = "Wailing Caverns", mates = { "Mario" } })
assert(PT.Mine().t == t0 + 30, "another dungeon counts")

-- I6: no guild level-up told at first: what is already there is the starting point
STUB.printed = {}
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("pt", { t = 5000, w = PT.Week() }), "GUILD", "Mario-Testrealm")
for _, line in ipairs(STUB.printed) do assert(not line:find(L.GUILD_LEVEL_UP:sub(1, 10), 1, true), "no level-up for data that was already there") end
STUB.Advance(61)   -- settled
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421 }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("pt", { t = 9000, w = PT.Week() }), "GUILD", "Mario-Testrealm")
local told = false
for _, line in ipairs(STUB.printed) do if line:find(string.format(L.GUILD_LEVEL_UP, PT.Level(PT.GuildTotal())), 1, true) then told = true end end
assert(told, "a real level-up afterwards is told")

-- I7: a member who opens Recruit lands on the wall, and the Guild tab still works
STUB.iAmOfficer = false
B.ShowTab("recruit")
assert(B.tab == "feed" and ns.char.guildSub ~= "recruit", "not stuck: " .. tostring(B.tab))
B.tabs.guild.scripts.OnClick(B.tabs.guild)
assert(B.tab == "feed", "the Guild tab opens")

-- M3: Home follows the points
B.ShowTab("home")
local before = B.rows[2].group.text
ns.Points.AddSample("Luis", { t = 777 })
STUB.Advance(0.6)   -- changes redraw the open page at most twice a second
assert(B.rows[2].group.text ~= before, "Home redrawn when points change")
