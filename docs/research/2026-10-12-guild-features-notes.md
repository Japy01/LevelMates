# Guild features: notes for LevelMates

Prose notes on how another WoW Forever guild addon behaves, area by area. No code was taken; our versions are designed from these notes. See also [the sync practices](2026-10-12-guild-sync-practices.md).

## Forever client facts worth knowing
- The client is the Retail engine with Vanilla content. A function existing proves nothing: judge each one by what it returns.
- Addons cannot read the combat log. Auras come only through `C_UnitAuras`.
- `GetAverageItemLevel` is broken (it divides by 16). Compute the average yourself over 17 slots, counting only filled ones.
- "Secret values" (tooltip unit tokens, some GUIDs, health) throw on use. Test them in pcall before comparing them or doing arithmetic.
- Blocked from addon code:
  - the MOTD, guild notes, guild info, promote/demote/remove and guild invite;
  - workaround: secure macro buttons, or our own shared notes and MOTD.
- `GuildRoster` is missing; use `C_GuildInfo.GuildRoster`.
- The roster can be partial (fewer rows than `GetNumGuildMembers`). Never remove anyone and never count level-ups from a partial read.

## Groups ("runs") and the group builder
- A run has a dungeon, today/tomorrow, a time, a note (60 chars) and 5 slots (tank, healer, 3 damage).
- The leader takes a slot from the start. The leader can add people by hand (with a class-for-role check) and remove members.
- The leader is the authority: every join is answered with the full member list and a timestamp. Joins for a full role are ignored.
- Lifetime: up to 48 h ahead; the run lives until 1 h after its start.
- "Invite all" skips members the roster says are offline, skips yourself, and prints one summary line.
- Group builder:
  - for each dungeon, members whose level fits (up to 2 above the top), at least 2 of them;
  - declared roles first, highest level first;
  - then guessed tanks and healers by class (tank: warrior, druid, paladin; heal: priest, druid, shaman, paladin);
  - the rest as damage;
  - sorted by filled slots.
- Shared group quests:
  - each client sends its unfinished dungeon/elite/group quests (at most 15: id, tag, title);
  - sent 20 s after the last quest-log change, and only if the list changed;
  - shown when 2+ online members share one.

## Quest board
- Alt-click a quest in the quest log (hook both log title-button click functions) to post "looking for group". Alt-click again withdraws it.
- Fallback: a list of your own log with one button per quest.
- A post has the id, title, level, tag, zone header and up to 3 objectives (done or not).
- It lives 2 h and is withdrawn automatically when the quest is turned in. "Looking too" toggles your name on it.
- The detail view shows the seeker's objectives and your own progress on the same quest.

## Professions
- Recipes are only readable while your own profession window is open. Debounce the scan: 1.5 s of quiet after the events, because the first list belongs to the previous profession.
- Ignore windows that are not your own (linked, guild or NPC crafting). Check the profession and rank against your own profession info.
- Store and share item ids, plus spell ids for enchants: sorted, as base 36 differences.
- Send the full state 8 s after a real change.
- Plausibility checks:
  - ranks above 75, 150 and 225 need levels 10, 20 and 35;
  - drop entries after 60 days;
  - at login, remove what the game no longer reports.
- "Who can craft":
  - search by link, id or name;
  - each crafter shows online state, rank bar and data age;
  - an Ask whisper with a 60 s cooldown.
- Tooltip post-call on items: wishers, crafters. Disable the hook after its first error.
- Trainer hint: rank equal to the current maximum (below 300) means "visit trainer".

## Map
- Draw pins on the world map's scroll child, for the map being viewed. Convert zone points for continent maps through world positions.
- A 0.5 s ticker runs only while the map is open.
- Keep pins the same size on screen: scale by UI scale divided by canvas scale.
- Bundle 4+ pins within one pin width into one gold disc with a count. Never draw your own pin.
- Campfires: detect placement from `UNIT_SPELLCAST_SUCCEEDED` (spell back to item with `GetItemSpell`). Send the zone, map, position and item; show it 5 min to people in the same zone.
- Gathering highlights:
  - use the soft-interact console variables and `PLAYER_SOFT_INTERACT_CHANGED`;
  - identify herb and ore nodes by object id, or by name as a fallback;
  - attach a marker to the object's nameplate from `NAME_PLATE_UNIT_ADDED`;
  - save the previous variables and restore them when switched off.

## Guild
- Roster history:
  - compare roster snapshots: joined, rank up or down, no longer listed;
  - the first run is only a baseline;
  - mass-shrink guard: more than 5 people and more than half vanishing at once waits for confirmation;
  - keep 1000 entries.
- Shared notes and our own MOTD: newest wins; empty text is a delete that propagates. Notes 120 chars, MOTD 180.
- Alts with link strength: proven (same account file), set (by an officer), claimed (by sync). A weaker link never replaces a stronger one.
- Race to max level:
  - only level-ups seen live can be "first" or "first of class";
  - those found already at max are listed as "before tracking".

## Gear and talents
- Self gear: 19 slots, item ids and item level, captured when not in combat. Share id + ilvl + enchant only.
- The model for others: `DressUpModel` with race and sex plus `TryOn` per item. If the sex is unknown, no model.
- Talents of another class: a loadout string can't be decoded without that class's tree. Each client shares its own tree layout once per session, and the viewer decodes the export format against it.

## UI
- Semantic colour tokens and size tokens; each look swaps the token values. Fonts are lazy, with a size percentage.
- Feedback line at the window foot: 6 s, then a 1.5 s fade, click to dismiss. It goes to chat when the window is closed.
- "Really?":
  - the first click relabels the button in a danger colour;
  - a second click within 5 s confirms.
- Notifications:
  - kinds with their own switches;
  - an unread badge on the minimap button;
  - a strip under the minimap (10 s, held during combat);
  - a tray of the last 30 items or 2 h, each with one action;
  - muted for the first 20 s after login.
- Settings: task pages with a search over titles and hints. Hideable sections.
- Window: refuses to open in combat (secure buttons). Size clamped to the screen at load. Reset command.
- Level bar:
  - 12 optional fields;
  - XP/h over a rolling 15 min window;
  - kills counted from the XP-gain chat message.
- Ding banner on level up, about 8 s.
