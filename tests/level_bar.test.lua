-- the level bar: XP per hour over 15 minutes, time to level, time in the level, kills in the level; off by default
COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."
COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = "You gain %d experience."
STUB.player.xp = 0
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local LB = ns.LevelBar

assert(not (LB.frame and LB.frame:IsShown()), "off by default")
assert(LB.Rate() == nil and LB.TimeToLevel() == nil, "no samples: no rate, no division by zero")

-- 300 XP in 10 minutes → 1800 per hour
STUB.player.xp = 100; STUB.Fire("PLAYER_XP_UPDATE", "player")
STUB.Advance(600)
STUB.player.xp = 300; STUB.Fire("PLAYER_XP_UPDATE", "player")
local rate = LB.Rate()
assert(rate and math.abs(rate - 1800) < 5, "about 1800 XP/h (counted from when the bar started watching): " .. tostring(rate))
assert(math.abs(LB.TimeToLevel() - 700 / rate * 3600) < 2, "time to level: " .. tostring(LB.TimeToLevel()))

-- kills from the client's own message; quest XP does not count
STUB.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold dies, you gain 45 experience.")
STUB.Fire("CHAT_MSG_COMBAT_XP_GAIN", "You gain 200 experience.")
assert(LB.Kills() == 1, "one kill: " .. LB.Kills())

-- the bar: /lm barra shows it, again hides it (saved)
SlashCmdList.LEVELMATES("barra")
assert(LB.frame and LB.frame:IsShown() and ns.db.settings.levelBar == true, "shown and saved")
STUB.Advance(1.1)
assert(LB.frame.text.text:find("XP/h", 1, true), "the line: " .. tostring(LB.frame.text.text))
-- locked: dragging does not move it
local moved = false
LB.frame.StartMoving = function() moved = true end
ns.db.settings.levelBarLocked = true
LB.frame.scripts.OnDragStart(LB.frame)
assert(not moved, "locked")
ns.db.settings.levelBarLocked = false
LB.frame.scripts.OnDragStart(LB.frame)
assert(moved, "unlocked: moves")
SlashCmdList.LEVELMATES("barra")
assert(not LB.frame:IsShown() and ns.db.settings.levelBar == false, "hidden and saved")

-- a level-up: kills and time in the level restart, the XP across the level counts
STUB.Advance(60)
local inLevel = LB.TimeInLevel()
assert(inLevel >= 660, "time in the level so far: " .. inLevel)
STUB.player.xp = 50; STUB.player.level = 21
STUB.Fire("PLAYER_LEVEL_UP", 21)
STUB.Fire("PLAYER_XP_UPDATE", "player")
assert(LB.Kills() == 0 and LB.TimeInLevel() < 2, "a new level: kills and time restart")
assert(LB.lastLevelTime and LB.lastLevelTime >= 660, "how long the last level took, for the banner")
assert(LB.Rate() > rate, "the 750 XP across the level counted: " .. tostring(LB.Rate()))

-- a reload keeps the time in the level
STUB.Advance(120)
local saved = ns.char.levelStart
assert(saved and saved.level == 21, "kept with the character")
assert(LB.TimeInLevel() >= 120, "continues: " .. LB.TimeInLevel())
