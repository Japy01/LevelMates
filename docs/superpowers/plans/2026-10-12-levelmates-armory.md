# Armory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read and share my gear (ids, item levels, enchants, my own average, race and sex). Show a guildmate's average on their card and a Gear window with a paper doll and a 3D model. Show builds of every class on cards.

**Architecture:**
- **New `Gear.lua`:**
  - a debounced, out-of-combat read;
  - encoding;
  - the personal state `eq` via `Sync.Personal` (`helloGap = 600`);
  - storage of others' gear.
- **New `GearWindow.lua`:** the small book-style window with slot buttons and a `DressUpModel`.
- **`MateCard.lua`:** the average line and a "Gear" button.
- **`Builds.lua`:** store every class; `BU.Of` for any class; `BU.List` still filters to mine.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.1); node + fengari tests.

**Spec:** `docs/superpowers/specs/2026-10-12-levelmates-armory-design.md`

## Global Constraints

- **Slots:** 1–19. The average uses all of them except 4 (shirt) and 19 (tabard), over filled slots only, rounded.
- **Item level:** `C_Item.GetDetailedItemLevelInfo(link)`, else the 4th return of `GetItemInfo`. The enchant comes from `item:id:enchant` in the link.
- **`eq` fields:**
  - `g` = "slot:id:ilvl:enchant,…" (up to 600 chars);
  - `a` (int 0–999);
  - `r` (int 1–100, race id from `UnitRace`'s third return);
  - `x` (int 2–3, `UnitSex`).
- **Reading:** read when the gear changes or at login, with 1 s of quiet; in combat, wait for `PLAYER_REGEN_ENABLED`.
- **Sharing:** new option `shareGear` (on); newcomers at most every 10 minutes.
- **Model:**
  - `SetUnit` when the person is a unit I can see (`UnitExists(name)` or a party/raid unit with that name);
  - else `SetCustomRace(r, x - 2)`, `Undress()` and `TryOn("item:" .. id)`;
  - no `r`/`x` → no model.
- **Policy:** nothing to chat; Lua 5.1; ask before pushing or tagging.

## Review Focus

1. Uncached items: `GetItemInfo` nil at read time → the item level is unknown, the id is still shared, and the read happens again when the info arrives (`GET_ITEM_INFO_RECEIVED`, throttled).
2. A guildmate on an older 0.4 build without `eq`: the card has no line and no button, and no errors.
3. Two-handed weapons (empty off hand): the average counts filled slots only.
4. Race and sex ids from Forever's custom races, if any: an out-of-range value means no model, never an error.
5. Builds of other classes: the Class tab still shows only my class.

---

### Task 1: `Gear.lua` (read, encode, share, store)

**Interfaces:**
- Produces:
  - `GE.Mine() → { slots = { [slot] = { id, il, en } }, avg, filled, r, x, t }`;
  - `GE.Of(name)`, same shape or nil;
  - `GE.Encode(slots)` and `GE.Decode(g)`;
  - `GE.Average(slots) → avg, filled`;
  - event `LM_GEAR_CHANGED`.
- Stubs: `GetInventoryItemLink("player", slot)` from `STUB.gear[slot]`; `C_Item.GetDetailedItemLevelInfo` from `STUB.ilvl[id]`; `UnitRace` / `UnitSex`; `PLAYER_EQUIPMENT_CHANGED`; `InCombatLockdown` from `STUB.inCombat`.

- [ ] **Step 1: failing test** (`tests/gear.test.lua`)
  - **Read:**
    - 14 filled slots, including a shirt and a tabard (ignored in the average), and an empty off hand;
    - the average equals the hand-computed value;
    - an enchant parsed from the link.
  - **Combat and debounce:**
    - in combat, nothing is read until regen;
    - three equipment changes within 1 s read once.
  - **Encoding:** round trip.
  - **Sharing:**
    - `eq` sent with `a` and `r`/`x`;
    - `shareGear` off → nothing.
  - **Receiving:** Mario's `eq` → `GE.Of("Mario").avg`.
  - **Uncached:** an item with no level → `il = 0` and it is excluded from the average, and a later `GET_ITEM_INFO_RECEIVED` re-reads.
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass and `npm test`. **Step 5:** commit `feat(gear): read and share my gear; my own item level average`.

### Task 2: Card line, Gear window, model; builds of every class

**Files:** `GearWindow.lua` (new), `MateCard.lua`, `Builds.lua`, locales. Test: `tests/gear_ui.test.lua`.

- [ ] **Step 1: failing test**
  - The card of Mario (with `eq`) shows `L.GEAR_LINE` with the average and filled count, and a `MC.gear` button.
  - Its click opens `ns.GearWindow.frame` with 19 slot buttons; slot 1's texture is the item icon (`GetItemIcon`/`C_Item.GetItemIconByID` stub), and a tooltip on enter.
  - `GW.model` gets `SetCustomRace` and `TryOn` per item when Mario is not a unit.
  - Without `eq`, the card has no line and no button.
  - Builds: a WARRIOR Mario's `tb`, seen by a MAGE me → `ns.Builds.Of("Mario")` returns it, and the card shows the build; `BU.List()` (Class tab) does not include him.
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass and `npm test`. **Step 5:** commit `feat(gear): the gear window with a paper doll and the model; builds of every class on cards`.

### Task 3: Docs and build

- CHANGELOG 0.4.0 and README in both languages: features, and privacy ("your gear, with Share my gear").
- `npm test`; copy to AddOns.
- Commit `docs: armory in the 0.4.0 notes`.
