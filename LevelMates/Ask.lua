-- Ask.lua: "Ask your class": a question goes to the guild as a sync record `ask` with my class (kept and handed over
-- by everyone for a day, so a late login of my class still sees it); guildmates of my class get a notice with an
-- [Answer] link that opens a whisper. The Class tab lists the last day's questions.
-- Specs 2026-10-10-levelmates-guild-tanda-design and 2026-10-12-levelmates-sync-v2-design.
local _, ns = ...
local A = {}
ns.Ask = A
local L, C, R, S = ns.L, ns.Comm, ns.Roster, ns.Sync
A.HOURS, A.GAP, A.MAX = 24, 60, 120

local function me() return ns.Me() end
local function myClass() return select(2, UnitClass("player")) end
local function newId() return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535)):sub(1, 8) end
local function store()
	ns.db.questions = ns.db.questions or {}
	local k = ns.GuildKey()
	ns.db.questions[k] = ns.db.questions[k] or {}
	return ns.db.questions[k]
end

function A.Link(name) return string.format("|Haddon:LevelMates:ask:%s|h|cff7ec8ff[%s]|r|h", name, L.ASK_ANSWER) end

local lastAsk = -math.huge
function A.Ask(text)
	text = strtrim((tostring(text or ""):gsub("[%c|]", " ")))
	if text == "" then return false end
	if GetTime() - lastAsk < A.GAP then ns.Say(L.ASK_WAIT); return false end
	text = ns.CutUtf8(text, A.MAX)
	if not C.IsReady() then ns.Say(L.ASK_FAILED); return false end
	local id = newId()
	S.Put("ask", id, { x = text, c = myClass() })
	lastAsk = GetTime()
	store()[id] = { by = me(), x = text, t = time(), mine = true }
	ns.Fire("LM_QUESTIONS_CHANGED")
	return true
end

local heardAt = {}   -- name -> when their last live question was taken: one a minute from each, whatever they send
S.Define("ask", { class = "board", life = A.HOURS * 3600, fields = { x = C.V.text(A.MAX), c = C.V.word(16) }, required = { "x", "c" },
	onChange = function(rec, old, how)
		if rec.dead or how == "mine" or how == "expired" or old then return end
		local name, f = rec.o, rec.d
		local m = R.mates[name]
		if f.c ~= myClass() or (m and m.class and m.class ~= f.c) then return end   -- only my class (the roster's word wins)
		local s = store()
		if s[rec.id] then return end
		if how == "live" then
			if GetTime() - (heardAt[name] or -math.huge) < A.GAP then return end
			heardAt[name] = GetTime()
		end
		s[rec.id] = { by = name, x = f.x, t = math.min(time(), rec.v) }
		ns.Fire("LM_QUESTIONS_CHANGED")
		if how == "live" and ns.db.settings.askNotices then   -- a question handed over at login is listed, not announced
			local text = string.format(L.ASK_NOTICE, name, f.x)
			ns.Say("%s %s", text, A.Link(name))
			ns.Screen(text)
		end
	end })

-- The last day's questions, newest first.
function A.List(search)
	local q, out, cutoff, s = (search or ""):lower(), {}, time() - A.HOURS * 3600, store()
	for id, e in pairs(s) do
		if e.t < cutoff then s[id] = nil
		elseif (e.mine or e.sim or R.IsGuildmate(e.by)) and (q == "" or (e.by .. " " .. e.x):lower():find(q, 1, true)) then
			out[#out + 1] = { id = id, by = e.by, x = e.x, t = e.t, mine = e.mine }
		end
	end
	table.sort(out, function(a, b) if a.t ~= b.t then return a.t > b.t end; return a.id < b.id end)
	return out
end

-- The link's click (a hardware event): a whisper to whoever asked.
function A.OnLink(link)
	local name = tostring(link):match("^addon:LevelMates:ask:([^:]+)")
	if not name then return false end
	ns.Board.Whisper(name)
	return true
end
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("SetItemRef", function(_, link) A.OnLink(link) end, A)
end

-- The box to write a question (Class tab button).
function A.OpenBox()
	StaticPopupDialogs["LEVELMATES_ASK"] = StaticPopupDialogs["LEVELMATES_ASK"] or {
		text = L.ASK_PROMPT, button1 = OKAY, button2 = CANCEL, hasEditBox = true, maxLetters = A.MAX, timeout = 0, whileDead = true, hideOnEscape = true,
		OnAccept = function(self) local eb = self.GetEditBox and self:GetEditBox() or self.EditBox; A.Ask(eb and eb:GetText()) end,
		EditBoxOnEnterPressed = function(self) local dialog = self:GetParent(); A.Ask(self:GetText()); dialog:Hide() end,
	}
	StaticPopup_Show("LEVELMATES_ASK")
end

function A.AddSample(by, text, minutesAgo) store()["sim" .. by] = { by = by, x = text, t = time() - (minutesAgo or 0) * 60, sim = true }; ns.Fire("LM_QUESTIONS_CHANGED") end
function A.RemoveSamples() local s = store(); for id, e in pairs(s) do if e.sim then s[id] = nil end end; ns.Fire("LM_QUESTIONS_CHANGED") end
