import assert from 'node:assert/strict';
import { Net } from '../tools/lua-net.mjs';

const net = new Net(['Ana', 'Ben']);
for (const [player, reversed] of [['Ana', false], ['Ben', true]]) {
  net.run(player, `local _,ns=...
    local t = ns.Sync.Store("lk")
    local now = GetServerTime()
    t.first = {id="first", o="Ana", v=now + ${reversed ? 20 : 10}, e=now+100, d={}}
    t.second = {id="second", o="Ana", v=now + ${reversed ? 10 : 20}, e=now+100, d={}}`);
}
const digest = player => net.run(player, 'local _,ns=...; local n,sum=ns.Sync.Digest("lk"); assert(n==2); return sum');
assert.notEqual(digest('Ana'), digest('Ben'));
console.log('ok swapped revisions differ even at the same record count and revision sum');
