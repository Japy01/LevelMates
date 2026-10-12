// tests/feed_sync.net.mjs: a wall entry outlives its author's session
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris']);
net.leave('Cris');
net.advance(5);
net.run('Ana', 'local _, ns = ...; ns.Feed.Share("lvl", 21)');
net.advance(3);
net.leave('Ana');
net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(15);
const got = net.run('Cris', 'local _, ns = ...; for _, e in ipairs(ns.Feed.List()) do if e.who == "Ana" and e.k == "lvl" then return e.a end end; return 0');
if (got !== 21) { console.error('Cris does not see Ana on the wall:', got); process.exit(1); }
console.log('ok tests/feed_sync.net.mjs');
