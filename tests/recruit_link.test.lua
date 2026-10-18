-- {enlace}/{link} in a recruitment template: the invite link of a community I belong to (the game's own
-- "[Join: Name]" link, from a ticket that still has uses); nothing when there is none; the link survives the
-- 255-byte cut (the words are trimmed, never the link); a template cannot carry a pasted link (its | is stripped)
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildRoles = { Tester = 2 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local RC, L = ns.Recruit, ns.L
-- no community: the placeholder vanishes
assert(RC.CommunityLink() == nil, "no community, no link")
assert(RC.Expand("Hola {enlace}.") == "Hola .", "the placeholder vanishes: " .. RC.Expand("Hola {enlace}."))
-- a community with a usable ticket (and the guild itself, which never has one)
Enum.ClubType = { BattleNet = 0, Character = 1, Guild = 2, Other = 3 }
local requested = {}
C_Club.GetSubscribedClubs = function() return { { clubId = 1, name = "Test Guild", clubType = 2 }, { clubId = 7, name = "En construcción", clubType = 1 } } end
C_Club.RequestTickets = function(id) requested[#requested + 1] = id end
C_Club.GetTickets = function(id)
	if id == 7 then return { { ticketId = "AbCd1234", allowedRedeemCount = 0, currentRedeemCount = 3 } } end
	return {}
end
CLUB_INVITE_HYPERLINK_TEXT = "Unirse a: %s"
RC.RequestLinks()
assert(#requested == 1 and requested[1] == 7, "tickets asked for the community only: " .. #requested)
local link = RC.CommunityLink()
assert(link and link:find("|HclubTicket:AbCd1234|h", 1, true) and link:find("[Unirse a: En construcción]", 1, true), "the game's link: " .. tostring(link))
assert(RC.Expand("Únete: {enlace}") == "Únete: " .. link, "expanded")
-- a used-up ticket is skipped
C_Club.GetTickets = function(id) if id == 7 then return { { ticketId = "Old", allowedRedeemCount = 5, currentRedeemCount = 5 }, { ticketId = "New", allowedRedeemCount = 5, currentRedeemCount = 1 } } end; return {} end
assert(RC.CommunityLink():find("New", 1, true), "the ticket with uses left")
-- long words: trimmed before the link, which stays whole and last
local long = string.rep("a", 300) .. " {enlace}"
local out = RC.Expand(long)
assert(#out <= 255 and out:sub(-#RC.CommunityLink()) == RC.CommunityLink(), "the link whole at the end: " .. #out)
-- a template cannot smuggle a raw link
RC.SetTemplate(1, "x |HclubTicket:Z|h[y]|h")
assert(not RC.Templates()[1]:find("|", 1, true), "bars stripped from templates")
print("ok")
