import assert from 'node:assert/strict';
import { Net } from '../tools/lua-net.mjs';

const net = new Net(['Ana', 'Ben', 'Cris', 'Dani']);
for (const player of ['Ana', 'Ben', 'Cris', 'Dani']) {
  net.run(player, `local _, ns = ...
    STUB.guildRoles = { Ana=4, Ben=2, Cris=2, Dani=4 }
    ns.Roster.InvalidateGuildRoster()
    IsInRaid = function() return true end
    GetNumGroupMembers = function() return 4 end
    for i, name in ipairs({"Ana", "Ben", "Cris", "Dani"}) do
      STUB.units["raid" .. i] = { name = name }
    end
    UnitIsGroupLeader = function(unit) return unit == "raid1" end`);
}
net.advance(5);
net.run('Ben', 'local _, ns = ...; assert(ns.LootRaid.SetRules({boss=10,att=5}))');
net.advance(8);
net.leave('Dani');
net.run('Ana', `local _, ns = ...
  local request = { g="raidsession", b=1, p=10, r="Boss", n="Ana,Ben,Cris,Dani" }
  assert(ns.Comm.Whisper("dka", request, "Ben"))
  assert(ns.Comm.Whisper("dka", request, "Cris"))`);
net.advance(15);
for (const player of ['Ana', 'Ben', 'Cris']) {
  assert.equal(net.run(player, 'local _, ns = ...; return ns.Loot.Balance("Dani")'), 10, player);
}
net.leave('Ana');
net.join('Dani');
net.run('Dani', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(35);
assert.equal(net.run('Dani', 'local _, ns = ...; return ns.Loot.Balance("Dani")'), 10);
console.log('ok repeated DKP request converges and reaches a late joiner');

// Recover a partial batch from saved character state without re-crediting
// the player whose entry was already committed by the original attempt.
net.run('Ben', `local _, ns = ...
  local operation = "recovery:boss:1"
  assert(ns.Loot.Post("Dani", 7, "boss", "Recovery", {raid="recovery", operation=operation}))
  ns.char.lootAutomaticAwards = {
    [operation] = { guild=ns.GuildKey(), raid="recovery", boss=1,
      names={"Dani", "Cris"}, points=7, kind="boss", reason="Recovery" },
  }
  ns.Fire("LM_ANNOUNCED")
  assert(next(ns.char.lootAutomaticAwards) == nil)
  assert(ns.Loot.Balance("Dani") == 17)
  assert(ns.Loot.Balance("Cris") == 17)`);
net.advance(10);
assert.equal(net.run('Dani', 'local _, ns = ...; return ns.Loot.Balance("Dani")'), 17);
console.log('ok a partially posted DKP batch recovers from saved state');
