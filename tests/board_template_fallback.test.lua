-- If the journal-style template cannot be created, the board still opens with the basic frame.
local realCreate = CreateFrame
CreateFrame = function(kind, name, parent, template)
	if template == "ButtonFrameTemplate" then error("unknown template: ButtonFrameTemplate") end
	return realCreate(kind, name, parent, template)
end
ButtonFrameTemplate_HidePortrait = function() error("must not be called on the fallback frame") end
ButtonFrameTemplate_HideAttic = function() error("must not be called on the fallback frame") end
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.db.settings.style = "classic"
ns.Board.Toggle()
assert(ns.Board.frame and ns.Board.frame:IsShown(), "board still opens")
assert(ns.Board.frame.TitleText.text == ns.L.BOARD_TITLE .. " - Test Guild (1)", "title on the basic frame")
