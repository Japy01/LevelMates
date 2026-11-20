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
 S.Put(kind, "entry", {})
end
STUB.Advance(60)
local seen = {}
local first = #STUB.sent
assert(S.Hello())
STUB.Advance(8)
local pages = 0
for i = first + 1, #STUB.sent do
 local kind, fields = C.Decode(STUB.sent[i].msg)
 if kind == "hi" then
  assert(fields.s:sub(1, 2) == "~," and #fields.s <= 200)
  pages = pages + 1
  for covered in fields.s:gmatch(",([%w_]+):") do seen[covered] = true end
 end
end
assert(pages > 1, "expected multiple hello pages")
for kind in pairs(types) do assert(seen[kind], "hello omitted " .. kind) end
local start = #STUB.sent
STUB.Receive(C.PREFIX, C.Encode("hi", {s = "~,zz2:0:0"}), "GUILD", "Luis-Testrealm")
STUB.Advance(9)
for i = start + 1, #STUB.sent do
 local kind, fields = C.Decode(STUB.sent[i].msg)
 assert(kind ~= "hc" or fields.t ~= "zz1", "omitted type triggered catch-up")
end
