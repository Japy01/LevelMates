-- The board uses the journal-style ButtonFrameTemplate when the client has it, and falls back to the basic frame.
local realCreate = CreateFrame
local created = {}
CreateFrame = function(kind, name, parent, template)
	local f = realCreate(kind, name, parent, template)
	if template == "ButtonFrameTemplate" then   -- as in Mainline: the title lives in TitleContainer.TitleText
		f.TitleContainer = { TitleText = setmetatable({}, getmetatable(f.TitleText)) }
		f.TitleText = nil
		-- Mainline-style inset: TOPLEFT 30 below the top, BOTTOMRIGHT 30 above the bottom
		f.Inset = { GetPoint = function(_, i) if i == 1 then return "TOPLEFT", f, "TOPLEFT", 4, -30 end return "BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 30 end }
		created[#created + 1] = f
	end
	return f
end
local hidden
ButtonFrameTemplate_HidePortrait = function(f) hidden = f end
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.Board.Toggle()
assert(#created == 1 and ns.Board.frame == created[1], "board built from ButtonFrameTemplate")
assert(hidden == ns.Board.frame, "portrait hidden")
assert(ns.Board.frame.TitleContainer.TitleText.text == ns.L.BOARD_TITLE .. " (0)", "title set on TitleContainer.TitleText: " .. tostring(ns.Board.frame.TitleContainer.TitleText.text))
-- header and bottom controls follow the real anchors of the inset
assert(ns.Board.TOP == 30 + 60 and ns.Board.BOTTOM == 30, "layout derived from the inset: TOP=" .. tostring(ns.Board.TOP) .. " BOTTOM=" .. tostring(ns.Board.BOTTOM))
assert(ns.Board.CHROME == ns.Board.TOP + 16 + ns.Board.BOTTOM + 10, "chrome height follows: " .. tostring(ns.Board.CHROME))
assert(ns.Board.helpButton:GetHeight() + 4 <= ns.Board.BOTTOM, "help button under the inset")
