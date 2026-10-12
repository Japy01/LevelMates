// tests/recipes_sync.net.mjs: a guildmate who saw my recipes keeps them after I leave
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Ben']);
net.advance(5);
net.run('Ana', 'STUB.trade = { line = 171, rank = 120, max = 150, recipes = { { id = 2331, item = 858 } } }; STUB.Fire("TRADE_SKILL_SHOW")');
net.advance(15);
net.leave('Ana');
net.advance(200);
const got = net.run('Ben', 'local _, ns = ...; local w = ns.Recipes.WhoCrafts(858); return w[1] and (w[1].name .. "|" .. tostring(w[1].online)) or ""');
if (got !== 'Ana|false') { console.error('Ben sees:', got); process.exit(1); }
console.log('ok tests/recipes_sync.net.mjs');
