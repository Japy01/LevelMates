-- Home, prettier: numbers with icons and bars; panels with an ornate header (icon, band); my character with a portrait
-- and my items' icons; empty panels with a big faded icon (and an action); the wall with an icon per kind and the time
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local B, L = ns.Board, ns.L
STUB.items[5001] = "|cff0070dd|Hitem:5001::::::::20:::::::|h[Casco azul]|h|r"
ns.char.gear = { avg = 21, filled = 1, slots = { [1] = { id = 5001, il = 21 } } }
ns.Feed.AddSample("Mario", "lvl", 22, nil, 5)
ns.Feed.AddSample("Mario", "dth", 22, "Minas", 6)
B.Toggle(); B.ShowTab("home")
local DB = ns.Dashboard

-- 1: numbers with icons; bars under the guild level, my gear and the challenge
for i = 1, 4 do assert(DB.stats[i].icon and DB.stats[i].icon:IsShown() and DB.stats[i].icon.texture, "stat " .. i .. " has an icon") end
assert(DB.stats[1].bar:IsShown() and DB.stats[4].bar:IsShown() and DB.stats[3].bar:IsShown(), "bars on level, gear and challenge")
assert(not DB.stats[2].bar:IsShown(), "no bar on who is online")

-- 2: ornate headers: a band and an icon
for _, k in ipairs({ "me", "now", "groups", "quests", "where", "wall" }) do
	assert(DB[k].band and DB[k].band:IsShown() and DB[k].icon and DB[k].icon:IsShown(), k .. ": header band and icon")
end

-- 3: my character: a portrait, my items' icons with their quality border, empty slots faded
assert(DB.me.portrait and DB.me.portrait:IsShown(), "a portrait")
assert(#DB.me.gear == 17, "17 slots")
local head = DB.me.gear[1]
assert(head.filled and head.icon.texture == 1000 + 5001 and head.border:IsShown(), "the helmet's own icon, with its quality border")
assert(not DB.me.gear[2].filled and DB.me.gear[2].icon.desaturated and not DB.me.gear[2].border:IsShown(), "an empty slot, faded")

-- 4: empty panels: a big faded icon, and an action where there is one
assert(DB.quests.emptyIcon:IsShown() and DB.quests.hint:IsShown(), "quests empty: icon and hint")
assert(DB.groups.emptyIcon:IsShown() and DB.groups.emptyButton:IsShown(), "groups empty: icon and a button")
DB.groups.emptyButton.scripts.OnClick(DB.groups.emptyButton)
assert(B.tab == "lfg" and ns.GroupsView.frame:IsShown(), "the button opens Groups")
B.ShowTab("home")
-- the wall: an icon per kind, the time on the right
local w1 = DB.wall.items[1]
assert(w1:IsShown() and w1.icon:IsShown() and w1.icon.texture and w1.right.text and w1.right.text ~= "", "wall: icon and time")
assert(DB.wall.items[1].icon.texture ~= DB.wall.items[2].icon.texture, "different kinds, different icons")
