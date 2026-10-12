-- GuildNotes.lua: a note per member and our own message of the day, shared by everyone (on Forever an addon cannot
-- write the game's notes or MOTD). My own note I write; anyone's, and the MOTD, only officers — checked by everyone
-- who receives it, since the game only answers "may I?" for oneself. Spec 2026-10-12-levelmates-guild-design (1.2).
local _, ns = ...
local GN = {}
ns.GuildNotes = GN
local L, C, R, S = ns.L, ns.Comm, ns.Roster, ns.Sync
GN.LIFE = 365 * 86400

local function me() return ns.Me() end
local function changed() ns.Fire("LM_GUILDNOTES_CHANGED") end
local function noteText(v) return type(v) == "string" and #v <= 120 and not v:find("[%c|]") end
S.Define("gn", { class = "board", life = GN.LIFE, writerOwns = true,
	fields = { f = C.V.text(48), n = noteText }, required = { "f" },
	idOwner = function(id) return id:match("^%x+$") ~= nil end,
	accept = function(f, owner) return owner == f.f or R.IsOfficer(owner) end,   -- my own, or an officer
	may = function(rec, who) return who == (rec.d and rec.d.f) or R.IsOfficer(who) or (who == me() and GN.CanWrite(rec.d and rec.d.f)) end,
	onChange = changed })
S.Define("gmo", { class = "board", life = GN.LIFE, writerOwns = true,
	fields = { n = function(v) return type(v) == "string" and #v <= 180 and not v:find("[%c|]") end }, required = { "n" },
	accept = function(_, owner) return R.IsOfficer(owner) end,
	may = function(_, who) return R.IsOfficer(who) or (who == me() and GN.CanMotd()) end,
	onChange = function(rec, old, how)
		if how == "live" and not rec.dead and rec.d.n ~= "" and ns.db.settings.goalNotices then ns.Notice(L.MOTD_NEW, rec.o, rec.d.n) end
		changed()
	end })

-- The game's own permission when it has the call; otherwise being an officer.
function GN.CanWrite(name)
	if name == me() then return true end
	if CanEditPublicNote then return CanEditPublicNote() == true end
	return R.IAmOfficer() or R.IsOfficer(me())
end
function GN.CanMotd() if CanEditMOTD then return CanEditMOTD() == true end; return R.IAmOfficer() or R.IsOfficer(me()) end

local function clean(text, max) return ns.CutUtf8(strtrim((tostring(text or ""):gsub("[%c|]", " "))), max) end
-- name's note: text, who wrote it, when (server time); nil when none.
function GN.Note(name)
	local r = S.Get("gn", ns.NameKey(name))
	if r and r.d.n and r.d.n ~= "" then return r.d.n, r.o, r.v end
end
-- Called from a click (the Members list's "Write note").
function GN.SetNote(name, text)
	if not GN.CanWrite(name) then ns.Say(L.NOTE_NOT_ALLOWED); return false end
	return S.Put("gn", ns.NameKey(name), { f = name, n = clean(text, 120) })
end
function GN.Motd()
	local r = S.Get("gmo", "motd")
	if r and r.d.n ~= "" then return r.d.n, r.o, r.v end
end
function GN.SetMotd(text)
	if not GN.CanMotd() then ns.Say(L.NOTE_NOT_ALLOWED); return false end
	return S.Put("gmo", "motd", { n = clean(text, 180) })
end
