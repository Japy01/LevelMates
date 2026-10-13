// tests/groups_sync.net.mjs: a named raid Now (own split) and a scheduled Alterac travel with their sizes and slots
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben']);
net.advance(35);
const posted = net.run('Ana', 'local _, ns = ...; local a = ns.LFG.Post{ d = 190, x = 20, c = "T2H4D14", t = "Azuregos", role = "T" }; local b = ns.Meetups.Create{ d = 203, at = ns.Meetups.Now() + 60, role = "A" }; return tostring(a) .. "|" .. tostring(b)');
if (posted !== 'true|true') { console.error('Ana could not post:', posted); process.exit(1); }
net.advance(5);
const seen = net.run('Ben', `local _, ns = ...
local raid
for _, ad in pairs(ns.LFG.ads) do if ad.d == 190 then raid = ad end end
local av = ns.Meetups.List()[1]
if not raid or not av then return "missing" end
return raid.t .. "|" .. raid.size .. "|" .. ns.Activities.EncodeCaps(raid.caps) .. "|" .. av.d .. "|" .. av.size .. "|" .. ns.Activities.EncodeCaps(av.caps)`);
if (seen !== 'Azuregos|20|T2H4D14|203|40|A40') { console.error('Ben sees:', seen); process.exit(1); }
net.run('Ben', 'local _, ns = ...; for id, ad in pairs(ns.LFG.ads) do if ad.d == 190 then ns.LFG.Join(id, "H") end end');
net.advance(5);
const slots = net.run('Ana', 'local _, ns = ...; local s = ns.LFG.Slots(ns.LFG.mine); return (s.T[1] or "-") .. "|" .. (s.H[1] or "-")');
if (slots !== 'Ana|Ben') { console.error('Ana sees:', slots); process.exit(1); }
console.log('ok tests/groups_sync.net.mjs');
