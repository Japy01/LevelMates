// tests/runs_sync.net.mjs: two joins for the last healer slot; the leader places one; a late login sees the same
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris', 'Dani']);
net.leave('Cris'); net.advance(5);
net.run('Ana', 'local _, ns = ...; ns.Meetups.Create(5, ns.Meetups.Now() + 60, "", "T", false)');
net.advance(3);
net.run('Ben', 'local _, ns = ...; ns.Meetups.Join(ns.Meetups.List()[1].id, "H")');
net.run('Dani', 'local _, ns = ...; ns.Meetups.Join(ns.Meetups.List()[1].id, "H")');
net.advance(6);
net.leave('Ana'); net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(20);
const got = net.run('Cris', 'local _, ns = ...; local m = ns.Meetups.List()[1]; if not m then return "none" end; local s = ns.Meetups.Slots(m); return (s.T[1] or "-") .. "|" .. (s.H[1] or "-") .. "|" .. (s.waiting[1] or "-") .. "|" .. tostring(s.confirmed)');
const [t, h, w, c] = got.split('|');
if (t !== 'Ana' || !['Ben', 'Dani'].includes(h) || !['Ben', 'Dani'].includes(w) || h === w || c !== 'true') { console.error('Cris sees:', got); process.exit(1); }
console.log('ok tests/runs_sync.net.mjs');
