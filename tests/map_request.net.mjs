// tests/map_request.net.mjs: opening the map asks for positions; only those who share theirs answer
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben', 'Cris']);
net.run('Ben', 'local _, ns = ...; ns.db.settings.sharePos = true');
net.advance(40);
const count = (who) => net.run(who, 'local _, ns = ...; local n = 0; for _, s in ipairs(STUB.sent) do if (ns.Comm.Decode(s.msg)) == "hb" then n = n + 1 end end; return n');
const ben0 = count('Ben'), cris0 = count('Cris');
net.run('Ana', 'WorldMapFrame:Show(); WorldMapFrame:OnMapChanged()');
net.advance(8);
if (count('Ben') <= ben0) { console.error('Ben did not answer'); process.exit(1); }
if (count('Cris') !== cris0) { console.error('Cris answered without sharing'); process.exit(1); }
console.log('ok tests/map_request.net.mjs');
