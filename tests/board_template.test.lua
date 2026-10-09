-- The board uses the journal-style ButtonFrameTemplate when the client has it, and falls back to the basic frame.
local realCreate = CreateFrame
local created = {}
CreateFrame = function(kind, name, parent, template)
	local f = realCreate(kind, name, parent, template)
	if template == "ButtonFrameTemplate" then   -- as in Mainline: the title lives in TitleContainer.TitleText
		f.TitleContainer = { TitleText = setmetatable({}, getmetatable(f.TitleText)) }
		f.TitleText = nil
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
