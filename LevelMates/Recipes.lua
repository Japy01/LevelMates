-- Recipes.lua: what each one can craft. Mine are read from my own profession window (never someone else's), kept per
-- profession as item ids (and spell ids for enchants), and shared as personal state `rc` in a compact form: sorted
-- ids as base-36 differences. Then "who crafts this?" and a line in item tooltips.
-- Spec 2026-10-12-levelmates-recipes-design.
local _, ns = ...
local RC = {}
ns.Recipes = RC
local L, C, R = ns.L, ns.Comm, ns.Roster
RC.MAX, RC.TOP, RC.SETTLE = 800, 10000000, 1.5
RC.scans = 0

------------------------------------------------------------------ encoding
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function b36(n)
	local s = ""
	repeat local r = n % 36; s = DIGITS:sub(r + 1, r + 1) .. s; n = math.floor(n / 36) until n == 0
	return s
end
-- Sorted, without repeats, each as the difference from the one before, in base 36, joined with "-".
function RC.Encode(list)
	local sorted, seen = {}, {}
	for _, v in ipairs(list or {}) do if not seen[v] then seen[v] = true; sorted[#sorted + 1] = v end end
	table.sort(sorted)
	local parts, prev = {}, 0
	for _, v in ipairs(sorted) do parts[#parts + 1] = b36(v - prev); prev = v end
	return table.concat(parts, "-")
end
-- nil for anything that is not a clean list (a zero difference, too many, too big, a stray character).
function RC.Decode(s)
	if type(s) ~= "string" then return nil end
	if s == "" then return {} end
	if not s:match("^[0-9a-z%-]+$") then return nil end
	local out, prev = {}, 0
	for part in s:gmatch("[^%-]+") do
		local d = tonumber(part, 36)
		if not d or d <= 0 then return nil end
		prev = prev + d
		if prev > RC.TOP then return nil end
		out[#out + 1] = prev
		if #out > RC.MAX then return nil end
	end
	return out
end

------------------------------------------------------------------ my recipes
function RC.Mine() ns.char.recipes = ns.char.recipes or {}; return ns.char.recipes end

-- My window only: not linked, not the guild's view, not an NPC crafter; and the profession is one of mine.
local function myWindow()
	local T = C_TradeSkillUI
	if not (T and T.IsTradeSkillReady and T.IsTradeSkillReady()) then return false end
	for _, fn in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsTradeSkillGuildMember", "IsNPCCrafting" }) do
		if T[fn] and T[fn]() then return false end
	end
	return true
end
local function line()
	local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
	if type(info) ~= "table" or not info.professionID then return nil end
	return info.professionID, info.skillLevel or 0, info.maxSkillLevel or 0
end
function RC.Scan()
	if not myWindow() then return end
	local id, rank, max = line()
	if not id then return end
	local skills = ns.char.skills
	if skills and next(skills) and not skills[id] then return end   -- not one of my professions (as my skills know them)
	RC.scans = RC.scans + 1
	local items, spells = {}, {}
	for _, rid in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
		local info = C_TradeSkillUI.GetRecipeInfo(rid)
		if info and info.learned ~= false then
			local out = C_TradeSkillUI.GetRecipeOutputItemData and C_TradeSkillUI.GetRecipeOutputItemData(rid)
			local item = out and (out.itemID or tonumber(tostring(out.hyperlink or ""):match("item:(%d+)") or ""))
			if item then items[#items + 1] = item else spells[#spells + 1] = rid end
		end
	end
	local mine = RC.Mine()
	if #items + #spells == 0 and mine[id] then return end   -- an empty read never wipes a filled one
	local old = mine[id]
	local new = { r = math.min(450, rank), m = math.min(450, max), items = items, spells = spells, t = time() }
	mine[id] = new
	if not old or RC.Encode(old.items) ~= RC.Encode(items) or RC.Encode(old.spells) ~= RC.Encode(spells) or old.r ~= new.r or old.m ~= new.m then
		ns.Fire("LM_RECIPES_CHANGED", id)
	end
end

-- The first list after switching professions is still the previous one: read once things have been quiet 1.5 s.
local settleAt
local function later()
	settleAt = GetTime() + RC.SETTLE
	C_Timer.After(RC.SETTLE + 0.05, function()
		if settleAt and GetTime() >= settleAt then settleAt = nil; RC.Scan() end
	end)
end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", later)
