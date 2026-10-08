// Fails if a protected/click-only action appears outside an OnClick / slash / menu handler, or if the
// addon touches combat APIs. Static, conservative: a hit means "look at it".
//   node tests/policy.test.mjs [addon-dir]   (default: LevelMates)
import fs from 'node:fs';
import path from 'node:path';
const dir = process.argv[2] || 'LevelMates';
const CLICK_ONLY = /\b(SendChatMessage|C_PartyInfo\.InviteUnit|InviteUnit|QuestLogPushQuest|ChatFrameUtil\.SendTell|ChatFrame_SendTell)\s*\(/;
let bad = 0;
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.lua'))) {
  const lines = fs.readFileSync(path.join(dir, f), 'utf8').split(/\r?\n/);
  lines.forEach((line, i) => {
    if (CLICK_ONLY.test(line)) {
      // allowed only inside functions whose name says click/menu/slash, or the Board/Help action helpers
      const ctx = lines.slice(Math.max(0, i - 12), i + 1).join('\n');
      const ok = /OnClick|OnAccept|EditBoxOnEnterPressed|CreateButton\(|ns\.Slash\(|function [A-Z]\.(Invite|Whisper|Coming)\b/.test(ctx);
      if (!ok) { bad++; console.error(`${f}:${i + 1}: click-only action outside a click handler: ${line.trim()}`); }
    }
    if (/COMBAT_LOG_EVENT|UNIT_SPELLCAST|UNIT_AURA|C_UnitAuras|C_Spell\.GetSpellCooldown/.test(line)) { bad++; console.error(`${f}:${i + 1}: combat API: ${line.trim()}`); }
  });
}
if (bad) process.exit(1); else console.log('ok policy');
