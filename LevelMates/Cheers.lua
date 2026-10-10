-- Cheers.lua: a guildmate's level-up gets a chat line with a [Congratulate] link; its click whispers them.
-- The link is an addon link ("addon:LevelMates:cheer:<name>:<level>"), which the client hands to EventRegistry.
local _, ns = ...
local K = {}
ns.Cheers = K
local L = ns.L

function K.Link(name, level) return string.format("|Haddon:LevelMates:cheer:%s:%d|h|cff7ec8ff[%s]|r|h", name, level, L.CHEER) end

ns.On("LM_MATE_LEVELUP", function(name, level)
	if not ns.db.settings.levelNotices then return end
	local text = string.format(L.LEVELUP_NOTICE, name, level)
	ns.Say("%s %s", text, K.Link(name, level))
	ns.Screen(text)
end)

-- The link's click (a hardware event, so the whisper is allowed).
function K.Whisper(name, level) SendChatMessage(string.format(L.CHEER_TEXT, level), "WHISPER", nil, name) end
function K.OnLink(link)
	local name, level = tostring(link):match("^addon:LevelMates:cheer:([^:]+):(%d+)")
	if not name then return false end
	K.Whisper(name, tonumber(level))
	return true
end
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("SetItemRef", function(_, link) K.OnLink(link) end, K)
end
