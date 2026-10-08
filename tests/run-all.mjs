// Whole suite: Lua syntax, every harness test, policy checks. Exit 1 if anything fails.
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
let fail = 0;
const r0 = spawnSync('node', ['tools/check-lua.mjs', 'LevelMates'], { stdio: 'inherit' }); if (r0.status) fail++;
for (const t of fs.readdirSync('tests').filter(f => f.endsWith('.test.lua'))) {
  const r = spawnSync('node', ['tools/run-lua-test.mjs', 'LevelMates', 'tests/' + t], { stdio: 'inherit' }); if (r.status) fail++;
}
const r1 = spawnSync('node', ['tests/policy.test.mjs'], { stdio: 'inherit' }); if (r1.status) fail++;
process.exit(fail ? 1 : 0);
