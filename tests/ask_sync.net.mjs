// tests/ask_sync.net.mjs: a class question outlives its asker's session
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris']);
net.leave('Cris');
net.advance(5);
net.run('Ana', 'local _, ns = ...; ns.Ask.Ask("como hago el pull?")');
net.advance(3);
net.leave('Ana');
net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(15);
const got = net.run('Cris', 'local _, ns = ...; local q = ns.Ask.List()[1]; return q and (q.by .. "|" .. q.x) or ""');
if (got !== 'Ana|como hago el pull?') { console.error('Cris sees:', got); process.exit(1); }
console.log('ok tests/ask_sync.net.mjs');
