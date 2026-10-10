# Changelog

## 0.1.1

- Published on CurseForge too.

## 0.1.0

First release. English and Spanish.

### Guildmates
- Board of guildmates online with LevelMates: class icon, level, zone, group state, optional XP per hour; sort by level or zone, a "near my level" filter, a name search; right-click to invite, whisper or set a waypoint. Classic tabs under the window, a minimap button and a key binding.
- Leveling partner: guildmates within 3 levels who are also looking go to the top.
- Quest matching when you accept a quest (with Questie: who could pick it up); progress on shared quests while grouped, in the guildmate's tooltip.
- Guildmates who share their position on the world map; the busiest zone next to the heading.
- Rested XP next to the heading, with a notice at the maximum; opt-in sharing.

### Dungeons
- Dungeons tab with a card and artwork for each of the 14 dungeons, highlighted when it fits your level.
- Group ads (dungeon, roles, note; 20 minutes), joining a group from its card with a role, the poster's notices and invites.
- Meetups: a day and time, joined with a role, a reminder 15 minutes before.

### Goals and progress
- Guild goals set by officers (everyone to a level, a dungeon together, counters) with live progress and who is missing; personal goals.
- A private journal of your leveling, with your pace and a rough time to 60.
- A guild wall with the last 7 days: level-ups, dungeons with guildmates, rare loot, goals.

### Items and professions
- Wishlist and giveaways, matched both ways, with reservations and "wanted by / given away by" on item tooltips.
- Professions tab grouped by profession, with icons and rank bars.

### Help and notices
- Help requests with a waypoint and "On my way"; a panic key.
- Rare sightings with a [Waypoint] link; [Congratulate] on guildmates' level-ups; a newer-version notice; important notices also on screen.
- Copy for Discord: any tab as ready-to-paste Discord text.

### Officers
- Recruit tab: three shared templates with placeholders, posted to channel 2 or 1 with a click, a 10-minute wait shared by officers, an optional reminder.

### Under the hood
- Guild addon messages only, with a hidden temporary channel as fallback; small, validated, rate-limited, and nothing from combat. Every option to share has its own switch; position, quests, XP per hour and rested XP are off by default.
- `/lm sim` and its variants show fake guildmates, locally, to try everything alone.
