-- Questie.lua: optional, guarded. Without Questie nothing here does anything and everything returns nil.
-- API verified in the installed Questie: QuestieLoader:ImportModule("QuestieDB") gives the module, with
-- QuestieDB.IsDoable(questId) (judges the PLAYER's eligibility: completed, prerequisites, class, level)
-- and QuestieDB.QueryQuestSingle(questId, "requiredLevel").
local _, ns = ...
local Q = {}
ns.Questie = Q

local function db()
	if type(_G.Questie) ~= "table" or type(_G.QuestieLoader) ~= "table" then return nil end
	local mod = _G.QuestieLoader:ImportModule("QuestieDB")
	if type(mod) == "table" and type(mod.IsDoable) == "function" then return mod end
end

-- true / false when Questie can tell, nil when it is absent or errors. `level` is the level of the player
-- the question is about. IsDoable only knows about me, so this is "a quest like me could take": a rough
-- proxy for a guildmate who walks the same quest chain.
function Q.CanTake(questID, level)
	local ok, result = pcall(function()
		local mod = db()
		if not mod then return nil end
		local required = mod.QueryQuestSingle and mod.QueryQuestSingle(questID, "requiredLevel")
		if type(required) == "number" and type(level) == "number" and level < required then return false end
		return mod.IsDoable(questID) == true
	end)
	if ok then return result end
	return nil
end
