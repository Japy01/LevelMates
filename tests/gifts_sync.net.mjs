// tests/gifts_sync.net.mjs: an offer on the market outlives its seller's session
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris']);
net.leave('Cris');
net.advance(5);
net.run('Ana', 'STUB.items[765] = "|cffffffff|Hitem:765::::::::20:::::::|h[Silverleaf]|h|r"; local _, ns = ...; ns.Gifts.Add(STUB.items[765], 15000)');
net.advance(3);
net.leave('Ana');
net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(15);
const got = net.run('Cris', 'local _, ns = ...; for _, g in ipairs(ns.Gifts.List()) do if g.name == "Ana" then return g.id .. ":" .. tostring(g.price) end end; return ""');
if (got !== '765:15000') { console.error('Cris sees:', got); process.exit(1); }
console.log('ok tests/gifts_sync.net.mjs');
