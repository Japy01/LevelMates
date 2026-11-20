STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.Fire("PLAYER_ENTERING_WORLD", true, false)
STUB.Advance(30)
local S, C = ns.Sync, ns.Comm
local types = {}
for i = 1, 35 do
 local kind = "zz" .. i
 types[kind] = true
 S.Define(kind, { class = "board", life = 3600, fields = {} })
end
local seen = {}
for _ = 1, 8 do
 local start = #STUB.sent
 assert(S.Hello())
 STUB.Advance(2)
 local summary
 for i = start + 1, #STUB.sent do
  local kind, fields = C.Decode(STUB.sent[i].msg)
  if kind == "hi" then summary = fields.s end
 end
 assert(summary and summary:sub(1, 2) == "~," and #summary <= 200)
 for kind in summary:gmatch(",([%w_]+):") do seen[kind] = true end
end
for kind in pairs(types) do assert(seen[kind], "rotation omitted " .. kind) end
S.Put("zz1", "entry", {})
STUB.Advance(2)
local start = #STUB.sent
STUB.Receive(C.PREFIX, C.Encode("hi", {s = "~,zz2:0:0"}), "GUILD", "Luis-Testrealm")
STUB.Advance(9)
for i = start + 1, #STUB.sent do
 local kind, fields = C.Decode(STUB.sent[i].msg)
 assert(kind ~= "hc" or fields.t ~= "zz1", "omitted type triggered catch-up")
end
