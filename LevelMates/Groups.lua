-- Groups.lua: one list of groups, whatever they are made of. "Now" groups are LFG ads (mine included), scheduled ones
-- are runs not started yet; both in one shape for the views, with the actions routed to the right place.
-- Spec 2026-10-13-levelmates-groups-design.
local _, ns = ...
local GR = {}
ns.Groups = GR

local function fromAd(ad)
	local G, A = ns.LFG, ns.Activities
	local a = A.Get(ad.d)
	local slots = G.Slots(ad)
	local v = G.View(ad)
	v.src, v.name, v.kind = "now", A.Name(ad.d, ad.t), a and a.kind or "o"
	v.slots, v.count = slots, A.Count(slots, ad.caps)
	v.full = v.count >= ad.size
	v.myRole = ad == G.mine and ad.lr or G.myJoins[ad.id]
	v.mine = ad == G.mine
	v.note = ad.n
	return v
end
local function fromRun(m)
	local M, A = ns.Meetups, ns.Activities
	local a = A.Get(m.d)
	local slots = M.Slots(m)
	m.src, m.name, m.kind = "meet", A.Name(m.d, m.t), a and a.kind or "o"
	m.slots, m.count = slots, A.Count(slots, m.caps)
	m.full = m.count >= m.size
	m.mine = m.by == ns.Me()
	m.myRole = m.mine and m.role or M.MyRole(m.id)
	m.note = m.n
	return m
end

-- Now first (mine, then the newest), then scheduled by time; of one activity when given.
function GR.List(activity)
	local out, G, M = {}, ns.LFG, ns.Meetups
	if G.mine and (not activity or G.mine.d == activity) then out[#out + 1] = fromAd(G.mine) end
	for _, id in ipairs(G.List()) do
		local ad = G.ads[id]
		if ad and (not activity or ad.d == activity) then out[#out + 1] = fromAd(ad) end
	end
	local now = M.Now()
	for _, m in ipairs(M.List(activity)) do if m.at >= now then out[#out + 1] = fromRun(m) end end
	return out
end

-- The actions, each from a click.
function GR.Join(g, role)
	if g.src == "now" then return ns.LFG.Join(g.id, role) end
	return ns.Meetups.Join(g.id, role)
end
function GR.Leave(g)
	if g.src == "now" then return ns.LFG.Leave(g.id) end
	return ns.Meetups.Leave(g.id)
end
function GR.Cancel(g)   -- withdraw my Now group, or cancel my run
	if g.src == "now" then if g.mine then ns.LFG.Cancel(); return true end; return false end
	return ns.Meetups.Cancel(g.id)
end
function GR.Members(g)   -- everyone placed, in role order
	local out = {}
	for _, role in ipairs({ "T", "H", "D", "A" }) do for _, name in ipairs(g.slots[role] or {}) do out[#out + 1] = name end end
	return out
end
function GR.InviteAll(g) return ns.Board.InviteAll(GR.Members(g)) end
