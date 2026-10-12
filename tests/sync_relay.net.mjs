// tests/sync_relay.net.mjs: a board record reaches the others live, with its owner
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris']);
const define = 'local _, ns = ...; ns.Sync.Define("tst", { class = "board", life = 3600, fields = { n = ns.Comm.V.text(40) }, required = { "n" } })';
for (const n of ['Ana', 'Ben', 'Cris']) net.run(n, define);
net.advance(5);
net.run('Ana', 'local _, ns = ...; ns.Sync.Put("tst", "q1", { n = "Minas 21:00" })');
net.advance(5);
for (const who of ['Ben', 'Cris']) {
  const got = net.run(who, 'local _, ns = ...; local r = ns.Sync.Get("tst", "q1"); return r and (r.d.n .. "|" .. r.o) or ""');
  if (got !== 'Minas 21:00|Ana') { console.error(who, 'did not get it:', got); process.exit(1); }
}
console.log('ok tests/sync_relay.net.mjs');
