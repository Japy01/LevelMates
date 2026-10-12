// tests/sync_catchup.net.mjs: Ana posts and leaves; Cris logs in later and gets it from Ben or Dani (only one answers),
// and what Ana removed stays removed.
import { Net } from '../tools/lua-net.mjs';
const names = ['Ana', 'Ben', 'Cris', 'Dani'];
const net = new Net(names);
const define = 'local _, ns = ...; ns.Sync.Define("tst", { class = "board", life = 3600, fields = { n = ns.Comm.V.text(40) }, required = { "n" } })';
for (const n of names) net.run(n, define);
net.leave('Cris');
net.advance(5);
net.run('Ana', 'local _, ns = ...; ns.Sync.Put("tst", "q1", { n = "Minas 21:00" }); ns.Sync.Put("tst", "q2", { n = "Borrada" })');
net.advance(3);
net.run('Ana', 'local _, ns = ...; ns.Sync.Remove("tst", "q2")');
net.advance(3);
net.leave('Ana');
net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(15);
const got = net.run('Cris', 'local _, ns = ...; local r = ns.Sync.Get("tst", "q1"); return r and (r.d.n .. "|" .. r.o) or ""');
if (got !== 'Minas 21:00|Ana') { console.error('Cris did not catch up:', got); process.exit(1); }
const dead = net.run('Cris', 'local _, ns = ...; local r = ns.Sync.Store("tst")["q2"]; return r and (r.dead and "tomb" or "alive") or "none"');
if (dead === 'alive') { console.error('the removed one came back'); process.exit(1); }
const answers = net.run('Ben', 'local _, ns = ...; return ns.Sync.stats.answered or 0') + net.run('Dani', 'local _, ns = ...; return ns.Sync.stats.answered or 0');
if (answers !== 1) { console.error('answers:', answers); process.exit(1); }
console.log('ok tests/sync_catchup.net.mjs');
