STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
ns.char.groupsView = "catalog"   -- these checks are about the catalogue cards (the Groups section opens on Groups)
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local CA, B, L = ns.ChatAds, ns.Board, ns.L
assert(CA and ns.db.settings.readChatAds == true, "on by default")

-- what counts: a dungeon (name or abbreviation, either language, accents or not) and a group word
assert(CA.Parse("LFM DM need heal") == 5, "Deadmines by its abbreviation")
assert(CA.Parse("busco grupo para Minas de la Muerte") == 5, "Spanish name")
assert(CA.Parse("LF2M RFK tank y heal") == 12, "Razorfen Kraul")
assert(CA.Parse("Sima Ígnea, faltan 2 dps") == 2 and CA.Parse("sima ignea faltan dps") == 2, "accents or not")
assert(CA.Parse("SÍMA ÍGNEA busco") == 2, "capital accented letters too")
assert(CA.Parse("lfg |cffffd000|Hdungeon:5|h[Wailing Caverns]|h|r") == 4, "inside a link")
assert(CA.Parse("WTS Linen Cloth cheap") == nil, "no dungeon")
assert(CA.Parse("the deadmines are fun") == nil, "a dungeon without a group word")
assert(CA.Parse("admin need help with dmg") == nil, "whole words only")
assert(CA.Parse("busco grupo para mazmorras") == nil, "the word for dungeons is not the Stockade")
assert(CA.Parse("LFM SM lib") == 14 and CA.Parse("lfg cementerio") == 13, "Monastery wings")

-- hearing the chat
local function say(text, who, chan) STUB.Fire("CHAT_MSG_CHANNEL", text, who, "", "2. Trade", who, "", 0, 2, chan or "Trade") end
say("LFM DM need heal", "Pepe-Testrealm")
local ads = CA.For(5)
assert(#ads == 1 and ads[1].name == "Pepe" and ads[1].full == "Pepe-Testrealm" and ads[1].text == "LFM DM need heal", "one ad: " .. #ads)
say("LFM DM need tank", "Pepe-Testrealm")
assert(#CA.For(5) == 1 and CA.For(5)[1].text == "LFM DM need tank", "one per player: the newest")
say("LF1M WC heal", "Pepe-Testrealm")
assert(#CA.For(5) == 0 and #CA.For(4) == 1, "a new ad from them replaces the old one")
say("LFM DM need heal", "Tester-Testrealm")
assert(#CA.For(5) == 0, "mine do not count")
say("LFM DM need heal", "Ana-Testrealm", "LM1a2b3c4d")
assert(#CA.For(5) == 0, "never the addon's hidden channel")
issecretvalue = function(v) return v == "secret" end
say("secret", "Ana-Testrealm"); STUB.Fire("CHAT_MSG_CHANNEL", "LFM DM heal", "secret", "", "2. Trade", "", "", 0, 2, "Trade")
assert(#CA.For(5) == 0, "protected text is not read")
issecretvalue = nil
ns.db.settings.readChatAds = false
say("LFM DM need heal", "Ana-Testrealm")
assert(#CA.For(5) == 0, "the option stops it")
ns.db.settings.readChatAds = true
say("LFM DM need heal", "Ana-Testrealm")
assert(#CA.For(5) == 1, "Ana")
STUB.Advance(9 * 60)
say("busco minas", "Luis-Testrealm")
assert(#CA.For(5) == 2 and CA.For(5)[1].name == "Luis", "newest first")
STUB.Advance(61)
assert(#CA.For(5) == 1 and CA.For(5)[1].name == "Luis", "ten minutes each")

-- the card
B.ShowTab("lfg")
local card
for _, c in ipairs(B.cards) do if c.dungeonId == 5 then card = c end end
assert(card.count.text == string.format(L.CHAT_ADS, 1), "the card counts the chat: " .. tostring(card.count.text))
B.DungeonTooltip(card)
local hit
for _, line in ipairs(GameTooltip.lines) do if line:find("Luis", 1, true) and line:find("busco minas", 1, true) then hit = true end end
assert(hit, "the tooltip shows the ad")
local made = {}
MenuUtil.CreateContextMenu = function(owner, fn) local root = { CreateTitle = function() end, CreateButton = function(_, text, f) made[#made + 1] = { text = text, fn = f } end }; fn(owner, root) end
B.OpenDungeonMenu(5)
local whisper
for _, m in ipairs(made) do if m.text == string.format(L.CHAT_AD_WHISPER, "Luis") then whisper = m end end
assert(whisper, "whisper them from the card")
whisper.fn()
assert(STUB.lastTell == "Luis-Testrealm", "with their realm")
B.searchBox:SetText("luis"); B.search = "luis"; B.Refresh()
local shown = 0
for _, c in ipairs(B.cards) do if c:IsShown() then shown = shown + 1 end end
assert(shown == 1, "the search finds chat posters too")
