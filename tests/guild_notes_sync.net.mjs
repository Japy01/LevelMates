// tests/guild_notes_sync.net.mjs: an officer's message of the day outlives the session
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris']);
for (const n of ['Ana', 'Ben', 'Cris']) net.run(n, 'STUB.guildRoles = { Ana = 1 }; local _, ns = ...; ns.Roster.InvalidateGuildRoster()');
net.leave('Cris'); net.advance(5);
net.run('Ana', 'local _, ns = ...; ns.GuildNotes.SetMotd("Raid el viernes")');
net.advance(3);
net.leave('Ana'); net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(15);
const got = net.run('Cris', 'local _, ns = ...; local t, by = ns.GuildNotes.Motd(); return (t or "") .. "|" .. (by or "")');
if (got !== 'Raid el viernes|Ana') { console.error('Cris sees:', got); process.exit(1); }
console.log('ok tests/guild_notes_sync.net.mjs');
