// tests/meetups_sync.net.mjs: a meetup outlives its creator's session; a late login sees it with its joiners
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris']);
net.leave('Cris');
net.advance(5);
const made = net.run('Ana', 'local _, ns = ...; return ns.Meetups.Create(1, ns.Meetups.Now() + 120, "traed pociones") and "yes" or "no"');
if (made !== 'yes') { console.error('Ana could not create it'); process.exit(1); }
net.advance(3);
net.run('Ben', 'local _, ns = ...; local m = ns.Meetups.List()[1]; ns.Meetups.Join(m.id, "H")');
net.advance(3);
net.leave('Ana');
net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(15);
const got = net.run('Cris', 'local _, ns = ...; local m = ns.Meetups.List()[1]; return m and (m.by .. "|" .. (m.joined["Ben"] or "-") .. "|" .. (m.n or "")) or ""');
if (got !== 'Ana|H|traed pociones') { console.error('Cris sees:', got); process.exit(1); }
console.log('ok tests/meetups_sync.net.mjs');
