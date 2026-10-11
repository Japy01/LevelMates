-- Trainer.lua: a reminder when a level brings new spells. Visiting the class trainer records what cannot be learned
-- yet and at which level; leveling up names what is now waiting. Before any visit, even levels get a plain reminder.
-- Local only: nothing is sent. Spec 2026-10-10-levelmates-group-tanda-design.
local _, ns = ...
local T = {}
ns.Trainer = T
local L = ns.L

local function data() ns.char.trainer = ns.char.trainer or { spells = {} }; return ns.char.trainer end
function T.Pending() return data().spells end
-- Spells that came due with my levels and wait until I next visit a class trainer (for Home).
function T.Due() return data().due or {} end

local function classTrainer()
	if IsTradeskillTrainer and IsTradeskillTrainer() then return false end
	if C_Trainer and C_Trainer.GetTrainerType and Enum and Enum.TrainerType and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet then return false end
	return true
end

-- What the trainer offers later, read with the "unavailable" filter on (then put back as the player had it).
function T.Record()
	if not classTrainer() then return end
	data().due = {}   -- at a class trainer: what was due is learnable now
	if not GetNumTrainerServices then return end
	local was = GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter("unavailable")
	if not was and SetTrainerServiceTypeFilter then SetTrainerServiceTypeFilter("unavailable", true) end
	local spells, mine = {}, UnitLevel("player")
	local ok = pcall(function()
		for i = 1, GetNumTrainerServices() do
			local name, kind, _, level, rank = GetTrainerServiceInfo(i)
			if name and kind == "unavailable" and type(level) == "number" and level > mine then
				spells[#spells + 1] = { name = name, rank = rank ~= "" and rank or nil, level = level }
			end
		end
	end)
	if not was and SetTrainerServiceTypeFilter then SetTrainerServiceTypeFilter("unavailable", false) end   -- back as the player had it, always
	if not ok then return end
	local d = data()
	d.seen, d.spells, d.due = true, spells, {}   -- visited: what was due is now learnable or learned
end

local function label(s) return s.rank and (s.name .. " (" .. s.rank .. ")") or s.name end

function T.LevelUp(level)
	if not ns.db.settings.trainerNotices then return end
	local d = data()
	if not d.seen then
		if level >= 4 and level % 2 == 0 then ns.Notice(L.TRAINER_EVEN, level) end
		return
	end
	local due, keep = {}, {}
	for _, s in ipairs(d.spells) do if s.level <= level then due[#due + 1] = s else keep[#keep + 1] = s end end
	d.spells = keep
	d.due = d.due or {}
	for _, s in ipairs(due) do table.insert(d.due, s) end
	if #due == 0 then return end
	local names = {}
	for i = 1, math.min(4, #due) do names[i] = label(due[i]) end
	ns.Notice(L.TRAINER_NEW, level, #due, table.concat(names, ", ") .. (#due > 4 and "…" or ""))
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("TRAINER_SHOW"); ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, event, level)
	if event == "TRAINER_SHOW" then   -- after the game's own trainer window has finished opening, and never in combat
		C_Timer.After(0, function() if not (InCombatLockdown and InCombatLockdown()) then T.Record() end end)
	else T.LevelUp(level) end
end)
