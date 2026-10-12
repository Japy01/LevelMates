-- Scheduler.lua: one ticker for the addon's periodic jobs, and redraws that coalesce: a burst of changes redraws a
-- view once at once and once more at the end of a half-second window, never while it is hidden.
local _, ns = ...
local jobs, order, ticker = {}, {}, nil
local function tick()
	local now = GetTime()
	for _, key in ipairs(order) do
		local j = jobs[key]
		if j and now >= j.due - 0.01 then j.due = math.max(j.due + j.every, now); j.fn() end   -- tolerance: the ticker's own float steps
	end
end
function ns.Every(key, seconds, fn)
	if not jobs[key] then order[#order + 1] = key end
	jobs[key] = { every = seconds, fn = fn, due = GetTime() + seconds }
	if not ticker then ticker = C_Timer.NewTicker(0.2, tick) end
end
function ns.Cancel(key)
	jobs[key] = nil
	for i, k in ipairs(order) do if k == key then table.remove(order, i); break end end
end

ns.REDRAW_GAP = 0.5
local views = {}
function ns.OnRedraw(view, isVisible, redraw) views[view] = { visible = isVisible, redraw = redraw, last = -math.huge } end
function ns.Dirty(view)
	local v = views[view]
	if not v or not v.visible() then return end
	if v.waiting then return end
	local now = GetTime()
	if now - v.last >= ns.REDRAW_GAP then v.last = now; v.redraw(); return end
	v.waiting = true
	C_Timer.After(math.max(0, v.last + ns.REDRAW_GAP - now), function()
		v.waiting = false
		if v.visible() then v.last = GetTime(); v.redraw() end
	end)
end
