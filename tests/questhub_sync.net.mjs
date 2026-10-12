// tests/questhub_sync.net.mjs: a quest post outlives its author's session
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris']);
net.leave('Cris'); net.advance(5);
net.run('Ana', 'STUB.quests = { 555 }; local _, ns = ...; ns.Questhub.Post(555)');
net.advance(3);
net.leave('Ana'); net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(15);
const got = net.run('Cris', 'local _, ns = ...; local p = ns.Questhub.List()[1]; return p and (p.by .. "|" .. p.q) or ""');
if (got !== 'Ana|555') { console.error('Cris sees:', got); process.exit(1); }
console.log('ok tests/questhub_sync.net.mjs');
