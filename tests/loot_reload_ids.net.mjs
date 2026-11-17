// Re-executing Loot.lua resets module locals while preserving character/record stores.
// This is a deterministic harness reproduction, not an in-client reload test.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana']);
net.advance(5);
net.run('Ana', `local _, ns = ...
 STUB.guildRoles = { Ana = 2 }; ns.Roster.InvalidateGuildRoster()
 assert(ns.Loot.Post("Ana", 10, "adj", "Initial balance"))`);
const reload = () => net.run('Ana', fs.readFileSync('LevelMates/Loot.lua', 'utf8'));
reload();
net.run('Ana', 'local _, ns = ...; assert(ns.Loot.Post("Ana", 5, "adj", "Second entry"))');
assert.equal(net.run('Ana', 'local _, ns = ...; return ns.Loot.Balance("Ana")'), 15, 'same-second reload must append, not overwrite the first entry');
// An old/reset counter and a repeated clock also must not overwrite historical records.
net.run('Ana', 'local _, ns = ...; ns.char.lootSeq = nil');
reload();
net.run('Ana', 'local _, ns = ...; assert(ns.Loot.Post("Ana", 2, "adj", "Migrated counter"))');
assert.equal(net.run('Ana', 'local _, ns = ...; return ns.Loot.Balance("Ana")'), 17);
// Awards and +1 adjustments use the same allocator and must remain independent after reload.
net.run('Ana', 'local _, ns = ...; assert(ns.Loot.Award(9001, "Ana")); assert(ns.Loot.AdjustPlusOne("Ana", 1, "First"))');
reload();
net.run('Ana', 'local _, ns = ...; assert(ns.Loot.Award(9001, "Ana")); assert(ns.Loot.AdjustPlusOne("Ana", 1, "Second"))');
assert.equal(net.run('Ana', 'local _, ns = ...; return #ns.Loot.History()'), 2);
assert.equal(net.run('Ana', 'local _, ns = ...; return ns.Loot.PlusOne("Ana")'), 2);
// The signed-32-bit rollover bound also works in Fengari's integer representation.
net.run('Ana', 'local _, ns = ...; ns.char.lootSeq = 2147483647; assert(ns.Loot.Post("Ana", 1, "adj", "Rollover"))');
assert.equal(net.run('Ana', 'local _, ns = ...; return ns.Loot.Balance("Ana")'), 18);
assert.equal(net.run('Ana', `local _, ns = ...
 for _, kind in ipairs({"lk", "la", "lp"}) do
  for _, rec in ipairs(ns.Sync.List(kind)) do
   local f={id=rec.id,v=rec.v,e=rec.e}; for k,v in pairs(rec.d) do f[k]=v end
   assert(ns.Comm.Validate(kind,f), "allocator must preserve wire schema")
  end
 end
 return true`), true);
console.log('ok tests/loot_reload_ids.net.mjs');
