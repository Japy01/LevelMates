# Shared Recipes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:**
- Read my recipes from my own profession window and share them as compact personal state.
- Answer "who can craft this?" from the board's search on the Crafts tab, with a "Ask them" whisper.
- Show crafters in item tooltips.
- Show "train" hints.

**Architecture:**
- **`Recipes.lua` (new):**
  - base 36 delta encoding;
  - a debounced own-window scan;
  - per-profession storage, mine and others';
  - the personal `rc` state through `Sync.Personal` (blobs when large);
  - receive with plausibility checks;
  - a lazy item → crafters index;
  - search;
  - a tooltip post-call.
- **Board:**
  - the Crafts tab shows a "Who crafts it" section when the search matches recipe items;
  - a guildmate's recipe list view;
  - menu entries.
- **`Professions.lua`:** the train hint.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.1); node + fengari tests.

**Spec:** `docs/superpowers/specs/2026-10-12-levelmates-recipes-design.md`

## Global Constraints

- **Scan:**
  - only my own window (`IsTradeSkillLinked`, `IsTradeSkillGuild`, `IsTradeSkillGuildMember` and `IsNPCCrafting` all false);
  - the profession must be in `GetProfessions()` at the same rank;
  - debounce 1.5 s after `TRADE_SKILL_SHOW` / `TRADE_SKILL_LIST_UPDATE` / `TRADE_SKILL_DATA_SOURCE_CHANGED`;
  - an empty read never replaces a filled one.
- **Encoding:** sorted, unique ids; differences in base 36 joined with `-`. Decode refuses a difference of 0, more than 800 entries, ids above 10,000,000, and any bad character.
- **`rc` fields:** `p` (int 1–2000), `r`/`m` (int 0–450), `i` and `s` (strings up to 1800 chars). One message (or blob) per profession. Sent 8 s after a real change and on announce or hello.
- **Plausibility:** a rank above 75, 150 or 225 needs a character level of at least 10, 20 or 35 (from the heartbeat; an unknown level is accepted).
- **Storage:** forget others after 60 days.
- **Ask:** a whisper with the item link, at most once per person and item every 60 s, from a click only (the policy marker).
- **Tooltip:** one line with up to 3 names (online first) and "+N".
- **Train hint:** rank == max with max 75, 150 or 225 → Journeyman, Expert or Artisan.
- **General:** Lua 5.1. Nothing to chat without a click. Ask before pushing or tagging.

## Review Focus

1. A guildmate with a surname who crafts: whisper target, tooltip and lists keep the full name.
2. A recipe list of 300+ items: the blob path, and decode within the limits.
3. `GetItemInfo` returns nil for uncached items: search by name must not error and should fill in later.
4. Switching professions quickly in the window: only the settled one is read, and it is stored under the right line.
5. The tooltip hook firing for non-item tooltips or with nil data: no errors.

---

### Task 1: Encoding and the scan

**Files:**
- Create: `LevelMates/Recipes.lua` (`.toc` after `Professions.lua`)
- Stub: a `C_TradeSkillUI` fake driven by `STUB.trade`
- Test: `tests/recipes_scan.test.lua`

**Interfaces:**
- Produces:
  - `RC.Encode(list) → string` and `RC.Decode(str) → list or nil`;
  - `RC.Scan()`, run by the debounce;
  - `RC.Mine() → { [line] = { r, m, items = {ids}, spells = {ids}, t } }`;
  - event `LM_RECIPES_CHANGED`.

- [ ] **Step 1: failing test**
  - Encode and decode 200 random ids round-trip; duplicates and unsorted input are handled.
  - Decode rejects `"0"`, `"a-0"`, 801 entries and `"zz!"`.
  - With `STUB.trade` holding Alchemy 171 (rank 120/150) and 3 recipes (two items, one enchant spell), firing `TRADE_SKILL_SHOW` and advancing 2 s gives `RC.Mine()[171].items` with 2 ids and `.spells` with 1.
  - A linked window (`STUB.trade.linked = true`) is ignored.
  - An empty `GetAllRecipeIDs` keeps the earlier list.
  - Three events within 1 s scan once.
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass and `npm test`. **Step 5:** commit `feat(recipes): read my recipes from my own profession window`.

### Task 2: Sharing and receiving

**Files:**
- Modify: `Recipes.lua`
- Test: `tests/recipes_share.test.lua`, `tests/recipes_sync.net.mjs`

**Interfaces:**
- Produces:
  - `RC.Of(name) → { [line] = {…} }`;
  - `RC.WhoCrafts(itemId) → { { name, line, r, m, t, online } }`, online first, then rank;
  - `RC.Known() → {itemIds}` (for search by name).

- [ ] **Step 1: failing tests**
  - **Unit:**
    - after the scan, an `rc` goes out within 10 s, with `p = 171` and `i` decoding to my items;
    - a received `rc` from Mario (level 20, rank 120) is stored and `WhoCrafts(item)` lists him;
    - a received rank 230 from a level-12 Mario is ignored;
    - an entry older than 60 days is forgotten;
    - sharing off → nothing sent.
  - **Net:** Ana scans Alchemy and leaves; Cris logs in; `ns.Recipes.WhoCrafts(item)[1].name == "Ana"`. Personal state is not relayed, so Cris only learns it if Ana is online. The net test therefore checks that Ben, who was online when Ana shared, has it after Ana leaves, and that the data survives in Ben's store.
- [ ] **Step 2:** fail. **Step 3:** implement (`S.Personal("rc", buildList, { save = "recipesPending", worth = … , enabled = shareProfessions })`, with `C.SCHEMA.rc`). **Step 4:** pass and `npm test`. **Step 5:** commit `feat(recipes): share my recipes; know who crafts what`.

### Task 3: Search, the crafter rows, the ask, the recipe list

**Files:**
- Modify: `Recipes.lua` (`RC.Find(search)`, `RC.Ask(name, itemId)`), `Board.lua` (the Crafts tab section and menus, the `B.recipesOf` view)
- Locales
- Test: `tests/recipes_ui.test.lua`

**Interfaces:**
- Produces: `RC.Find(text) → {itemIds}`. It accepts an item link (`item:(%d+)`), a bare number, or a case-insensitive part of a known item's name (`GetItemInfo`); at most 10 results.

- [ ] **Step 1: failing test**
  - With Mario crafting item 858 ("Lesser Healing Potion" in `STUB.items`), `B.search = "healing"` on the Crafts tab shows a "who crafts" header for the item and a row for Mario.
  - Searching by a link or by `"858"` gives the same.
  - A right-click on Mario's row offers "Ask for [item]".
  - Clicking it whispers once (`STUB.lastChat.chatType == "WHISPER"`, the message holds the link); a second click within 60 s does not whisper again.
  - "Their recipes" shows his items as rows.
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass and `npm test`. **Step 5:** commit `feat(recipes): who crafts it, from the Crafts tab's search; ask with a whisper; their recipes`.

### Task 4: Tooltip and train hint

**Files:**
- Modify: `Recipes.lua` (tooltip post-call), `Professions.lua` / `Board.lua` (FillCrafts hint)
- Test: `tests/recipes_tooltip.test.lua`

- [ ] **Step 1: failing test**
  - `STUB.TooltipPost("Item", GameTooltip, { id = 858 })` adds a line naming Mario.
  - With 5 crafters: 3 names and "+2", online first.
  - Nil data → no error.
  - A crafts row with 75/75 shows the Journeyman hint; 300/300 shows none.
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass and `npm test`. **Step 5:** commit `feat(recipes): crafters in item tooltips; when to train`.

### Task 5: Docs and build

- CHANGELOG 0.4.0 bullet; README features and privacy ("your recipes, with Share professions") in both languages.
- `npm test`; copy to AddOns.
- Commit `docs: shared recipes in the 0.4.0 notes`.

---

## Self-review notes

- **Spec coverage:**
  - §1: Task 1;
  - §2: Task 2;
  - §3: Task 3;
  - §4 and §5: Task 4;
  - §6: Task 2;
  - §7: each task's tests.
- **Ruling against the spec:** spec §7 says a late login finds Ana's recipes after she left. That cannot work for personal state, which is never relayed (sync-v2 rule: only the owner publishes personal data). The net test checks what is true instead: a guildmate who saw them keeps them, and so does the late login once Ana is back. Relaying recipes would let anyone forge someone else's crafts.
