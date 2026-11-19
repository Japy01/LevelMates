import assert from 'node:assert/strict';
import { Net } from '../tools/lua-net.mjs';

const net = new Net(['Ana', 'Ben', 'Cris']);
net.leave('Cris');
for (const who of ['Ana', 'Ben', 'Cris']) {
  net.run(who, `local _, ns = ...
    STUB.guildRoles={Ana=4,Ben=2,Cris=4}
    ns.Roster.InvalidateGuildRoster()`);
}
const publish = (withdrawn) => net.run('Ana', `local _, ns = ...
  local id = ns.Sync.OwnerRecordId
  local mine = ns.Me()
  local class = select(2, UnitClass("player"))
  local off = ${withdrawn}
  assert(ns.Sync.Put("tbr", id(mine), off and {} or {c=class,s=71,l=20,p="1001:3"}))
  assert(ns.Sync.Put("wlr", id(mine), off and {} or {ids="858",p="858:1"}))
  assert(ns.Sync.Put("mcr", id(mine)..id("Patada"):sub(1,8), off and {n="Patada"}
    or {n="Patada",x="/cast Kick",c=class}))`);
const sharedCount = who => net.run(who, `local _, ns = ...
  local count = 0
  if ns.Builds.Of("Ana") then count=count+1 end
  if ns.Wishlist.WantedBy(858)[1]=="Ana" and ns.Wishlist.PriorityOf("Ana",858)==1 then count=count+1 end
  if #ns.Macros.Guild("Patada")==1 then count=count+1 end
  return count`);
net.advance(10);
publish(false);
net.advance(10);
assert.equal(sharedCount('Ben'), 3);
net.leave('Ana');
net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(30);
assert.equal(sharedCount('Cris'), 3);
net.leave('Cris');
net.join('Ana');
net.advance(30);
publish(true);
net.advance(10);
assert.equal(sharedCount('Ben'), 0);
net.leave('Ana');
net.join('Cris');
net.run('Cris', 'local _, ns = ...; ns.Roster.Announce()');
net.advance(50);
assert.equal(sharedCount('Cris'), 0);
console.log('ok offline build, wishlist and macro snapshots and withdrawals');
