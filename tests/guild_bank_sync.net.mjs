// tests/guild_bank_sync.net.mjs: the bank snapshot reaches a late login
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris']);
net.leave('Cris'); net.advance(5);
net.run('Ana', 'STUB.bank = { money = 500, tabs = { { name = "General", slots = { [1] = { id = 858, n = 4 } } } } }; STUB.Fire("GUILDBANKFRAME_OPENED"); STUB.Advance(3); STUB.Fire("GUILDBANKFRAME_CLOSED")');
net.advance(8);
net.leave('Ana'); net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(20);
const got = net.run('Cris', 'local _, ns = ...; local s = ns.GuildBank.Snapshot(); return s and (s.by .. "|" .. (s.tabs[1].items[858] or 0)) or ""');
if (got !== 'Ana|4') { console.error('Cris sees:', got); process.exit(1); }
console.log('ok tests/guild_bank_sync.net.mjs');
