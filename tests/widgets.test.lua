-- the widget kit on parchment
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
local W, L, SK = ns.Widgets, ns.L, ns.Skin
local parent = CreateFrame("Frame", nil, UIParent)
-- panel
local p = W.Panel(parent, "Ahora")
assert(p.title.text == "Ahora" and p.right and p.hint, "panel parts")
p:SetHint("Nadie busca grupo."); p:SetEmpty(true)
assert(p.hint:IsShown() and p.hint.text == "Nadie busca grupo.", "hint shown when empty")
p:SetEmpty(false); assert(not p.hint:IsShown(), "hint hidden with content")
-- stat
local s = W.Stat(parent)
s:Set("23", "nivel de objeto", "14/17")
assert(s.value.text == "23" and s.label.text == "nivel de objeto" and s.sub.text == "14/17", "stat texts")
-- pill
local pill = W.Pill(parent)
pill:Set("● 3")
assert(pill.text.text == "● 3" and pill:GetWidth() > 0, "pill")
-- chip
local chip = W.Chip(parent, "Hoy")
chip:SetChecked(true); assert(chip.checked, "chip checked")
chip:SetChecked(false); assert(not chip.checked, "chip unchecked")
-- role slot
local slot = W.Slot(parent)
slot:Set("H", "Mario", "PRIEST")
assert(slot.name.text == "Mario" and slot.icon:IsShown(), "a filled slot")
slot:Set("T")
assert(slot.name.text == L.ROLE_T and slot.empty, "an empty slot shows its role")
assert(slot.icon:IsShown() and slot.icon.texture == W.ROLE_ICON and slot.icon.desaturated, "an empty slot: its role icon, greyed")
slot:Set("D", "Pepe", nil)
assert(slot.icon:IsShown() and slot.icon.texture == W.ROLE_ICON and not slot.icon.desaturated, "class unknown: the role icon, not a wrong class")
-- confirm button
local done = 0
local b = W.ConfirmButton(parent, "Cancelar", function() done = done + 1 end)
b.scripts.OnClick(b)
assert(done == 0 and b.text == L.CONFIRM_SURE, "first click asks")
b.scripts.OnClick(b)
assert(done == 1 and b.text == "Cancelar", "second click does it")
b.scripts.OnClick(b); STUB.Advance(6)
assert(b.text == "Cancelar", "it goes back after 5 s")
b.scripts.OnClick(b); b:Reset()
assert(b.text == "Cancelar" and not b.pending, "reset clears a pending ask")
-- the popup for menus
local accepted = false
ns.Confirm("¿Seguro que quieres cancelar la partida?", function() accepted = true end)
assert(STUB.lastPopup == "LEVELMATES_CONFIRM", "a popup")
StaticPopupDialogs.LEVELMATES_CONFIRM.OnAccept(STUB.lastDialog)
assert(accepted, "accepting does it")
-- ink: their texts are registered
local inked = 0
for _, fs in ipairs(SK.inkList) do if fs == p.title or fs == s.value then inked = inked + 1 end end
assert(inked == 2, "texts in ink")
