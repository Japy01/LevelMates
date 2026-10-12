// tests/net_smoke.net.mjs: two clients see each other's heartbeat through the harness
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben']);
net.advance(5);
const seen = net.run('Ben', 'local _, ns = ...; return ns.Roster.mates["Ana"] and ns.Roster.mates["Ana"].level or 0');
if (seen !== 20) { console.error('Ben does not see Ana:', seen); process.exit(1); }
console.log('ok tests/net_smoke.net.mjs');
