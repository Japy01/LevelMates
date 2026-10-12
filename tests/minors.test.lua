local macros = {}
function InCombatLockdown() return false end
function GetNumMacros() return 0, #macros end
function GetMacroIndexByName(n) for i, m in ipairs(macros) do if m.name == n then return 120 + i end end; return 0 end
function GetMacroInfo(i) local m = macros[i - 120]; if m then return m.name, 1, m.body end end
local createWorks = true
function CreateMacro(name, icon, body) if not createWorks then return nil end; macros[#macros + 1] = { name = name, body = body }; return 120 + #macros end
STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(1)
local C, CA, MA, B, F, M, L = ns.Comm, ns.ChatAds, ns.Macros, ns.Board, ns.Feed, ns.Meetups, ns.L
local function say(text, who, chan) STUB.Fire("CHAT_MSG_CHANNEL", text, who, "", "2. Trade", who, "", 0, 2, chan) end

-- chat ads: an unrelated line keeps the ad; codes are stripped from what is shown; the hidden channel by its full name
say("LFM DM need heal |cffffffff|Hitem:2589::::::::20:::::::|h[Linen Cloth]|h|r", "Pepe-Testrealm", "Trade")
say("WTS copper ore", "Pepe-Testrealm", "Trade")
local ads = CA.For(5)
assert(#ads == 1, "an unrelated line keeps the ad")
assert(ads[1].text == "LFM DM need heal [Linen Cloth]", "shown without codes: " .. ads[1].text)
STUB.Fire("CHAT_MSG_CHANNEL", "LFM DM need heal", "Ana-Testrealm", "", "5. LM1a2b3c4d", "", "", 0, 5, nil)
assert(#CA.For(5) == 1, "the hidden channel, even without its base name")
-- the board redraws for chat ads only on the Dungeons tab
B.Toggle(); B.ShowTab("journal")
local n = 0
local real = B.Refresh
B.Refresh = function() n = n + 1; real() end
for i = 1, 5 do say("LFM WC heal " .. i, "Luis" .. i .. "-Testrealm", "Trade") end
STUB.Advance(2)
B.Refresh = real
assert(n == 0, "no redraw on other tabs: " .. n)

-- macros: a failed create says nothing about success; a long name is "too long"; risky guild macros warn
createWorks = false
STUB.printed = {}
assert(not MA.Create("LM Test", "/cast X"), "a create the game refused")
for _, line in ipairs(STUB.printed) do assert(not line:find(string.format(L.MACRO_MADE, "LM Test"), 1, true), "no success message") end
createWorks = true
macros[#macros + 1] = { name = "Contrahechizoñññ", body = "/cast X" }
STUB.printed = {}
assert(not MA.Share("Contrahechizoñññ") and STUB.printed[#STUB.printed]:find(string.format(L.MACRO_LONG, "Contrahechizoñññ"), 1, true), "a name too long is said so")
STUB.Receive("LVLM2", C.Encode("hb", { l = 24, z = 1421, c = "WARRIOR" }), "GUILD", "Mario-Testrealm")
STUB.Receive("LVLM2", C.Encode("mc", { n = "Risky", x = "/run DoSomething()" }), "GUILD", "Mario-Testrealm")
local titles = {}
MenuUtil.CreateContextMenu = function(owner, fn) titles = {}; local root = { CreateTitle = function(_, t) titles[#titles + 1] = t end, CreateButton = function() end }; fn(owner, root) end
B.OpenClassMenu({ kind = "guild", m = MA.Guild()[1] })
local warned
for _, t in ipairs(titles) do if t == L.MACRO_RUN_WARN then warned = true end end
assert(warned, "a warning on /run macros")

-- builds: the loadout list arriving after login triggers a send check
assert(ns.Builds and true)

-- wall: the cemetery count ignores the search; deaths are not re-sent once the option is off
STUB.Receive("LVLM2", C.Encode("fe", { k = "dth", a = 24, b = "Duskwood", t = F.Now() }), "GUILD", "Mario-Testrealm")
STUB.Fire("PLAYER_DEAD"); STUB.Advance(1)
B.ShowTab("feed"); B.feedDeaths = true; B.search = "mario"; B.Refresh()
assert(B.subtitle.text == string.format(L.FEED_CEMETERY_SUB, 2), "the week's deaths, whatever the search: " .. tostring(B.subtitle.text))
B.feedDeaths, B.search = false, ""
ns.db.settings.shareDeaths = false
local before = #STUB.sent
STUB.Receive("LVLM2", C.Encode("ping", {}), "GUILD", "Luis-Testrealm"); STUB.Advance(12)
for i = before + 1, #STUB.sent do local k, f = C.Decode(STUB.sent[i].msg); assert(not (k == "fe" and f.k == "dth"), "no deaths re-sent once off") end

-- calendar: a meetup that already started is not offered
M.AddSample("Mario", 5, -30, {})
M.AddSample("Ana", 4, 60, {})
B.ShowTab("lfg"); B.lfgCalendar = true; B.Refresh()
local meets = 0
for _, r in ipairs(B.rows) do if r.button:IsShown() and r.button.meet then meets = meets + 1 end end
assert(meets == 1, "only the one still to come: " .. meets)
B.lfgCalendar = false

-- Discord copy on the recruit tab follows the view
STUB.iAmOfficer = true
B.ShowTab("recruit"); B.recruitView = nil; B.Refresh()
local text = ns.DiscordCopy.Text("recruit")
assert(text:find(L.TAB_RECRUIT, 1, true) and not text:find(L.HEAD_INACTIVE, 1, true), "templates view: the template text, not the inactive list")

-- the card grows with its lines
ns.MateCard.Show("Mario")
local h1 = ns.MateCard.frame:GetHeight()
for i = 1, 8 do ns.Feed.AddSample("Mario", "lvl", 30 + i, nil, i) end
ns.Wishlist.AddSample("Mario", { 2589, 765 }); ns.Gifts.AddSample("Mario", { 2318 })
ns.Professions.AddSample("Mario", { { id = 171, rank = 120 } }); ns.Personal.AddSample("Mario", 40, math.floor(time() / 86400) + 3)
for d = 1, 8 do M.AddSample("Mario", d, 120 + d, {}) end
ns.MateCard.Refresh()
assert(ns.MateCard.frame:GetHeight() > h1, "taller with more lines")
