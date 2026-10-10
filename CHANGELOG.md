# Changelog

## 0.1.0 (unreleased)

First version.

- Board of online guildmates who run the addon: name, level, zone, group state, optional XP per hour.
- Quest matching: a line when a guildmate on your map has the quest you just accepted; optional
  "could pick up" line when Questie is installed.
- Help requests: ask for a hand with an elite, guildmates get a notice and a map waypoint, "On my way"
  whispers the asker from a click.
- Options page with a switch for everything you share. Position, quests and XP per hour are off by default.
- Transport over guild addon messages, with a hidden temporary channel as fallback. Only the addon's own
  messages travel; nothing from combat.
- English and Spanish.
- `/lm sim` shows fake guildmates, locally, to try the addon alone.
- Inside instances only help requests are sent.
- The help prompt says that asking for help shares your position; only the asker can clear a request.
- Board: click the level or zone header to sort, and a "near my level (±5)" filter. Both are remembered per character.
- A key binding to show or hide the board (Key Bindings > AddOns > LevelMates).
- A help request closes by itself when the asker groups with someone who pressed "On my way" (new message kind `helpgo`; older versions ignore it).
- Board: journal-style frame, a heading with subtitle and a name search box. Board look: window height follows the list, title shows the count, the sorted header shows its direction, group and level are colour-coded, striped rows with hover highlight, and the filter checkbox is now visible.
- A minimap button: left-click shows or hides the board, right-click opens the options, drag moves it. The "Minimap button" option shows or hides it right away.
- Board rows show the class icon.
- Dungeon groups: a "Dungeons" tab on the board and a "Find a group" dialog (dungeon, roles, short note). Ads last 20 minutes, one per player, only the author can withdraw it; a chat line shows when an ad fits your level (option in the settings). Starts with six dungeons. New message kinds `lfg` and `lfgx`; older versions ignore them.
- Leveling partner: a "Looking for a partner" check box on the Guildmates tab; matches (within 3 levels, both ticked) go to the top, tinted, with a one-time chat line; it turns off when you group with one of them. New message kind `pal`; older versions ignore it.
- Rested XP: yours next to the board heading and a chat line at the maximum; opt-in sharing (off by default) shows it to guildmates on hover. New message kind `rx`; older versions ignore it.
- Journal: a third board tab with a private, per-character record (levels with time per level, quests, dungeons with guildmates, groups, green-or-better items, profession milestones, deaths); filter, search, pages, clear with confirmation; at most 1000 entries. The board is now 600 wide.
- Guild goals: a fourth board tab; officers and the guild master create goals (everyone to a level, a dungeon together, a counter of levels, quests or dungeons); progress with who is missing; kept per guild and re-shared by officers; at most 5, they expire two days after their deadline. New message kinds `go`, `gx`, `gd`, `gc`.
- Personal goals: "My goal" on the Goals tab (a target level and a deadline, one per character), shown to guildmates with their level; announced when reached. New message kind `gp`.
- Wishlist: a fifth board tab (the tabs are now classic tabs under the window); up to 10 items per character added with Shift+click; shared with the guild; "Wanted by" on item tooltips; a notice when you loot a guildmate's wish. New message kind `wl`.
- Copy for Discord: a "Discord" button on the board puts the current tab (guildmates, dungeon groups, your week, goals, wishes) into a box as Discord text, at most one message long, selected for Ctrl+C.
- Headings and help line per board tab; your leveling pace on the Journal tab.
- Screen notices for the important events (option), a notice when a guildmate runs a newer LevelMates, and a [Congratulate] link on guildmates' level-ups (option).
- Professions: a sixth tab with who has each profession and its rank, shared in the new kind `pf` (option to stop sharing); in Copy for Discord too.
- Join a dungeon group from its card (new kinds `lfj`/`lfjx`): the poster is told, sees who joined, invites them, and hears when the group is full.
- Guild wall: a seventh tab with the last 7 days of level-ups, dungeons with guildmates, rare-or-better loot and goals; new kind `fe` (options to stop sharing, and to leave loot out).
- Giveaways on the Wishes tab, matched with wishes both ways; reservations; new kinds `gv`, `gr`.
- Dungeon meetups from the cards: day and time, join with a role, reminder 15 minutes before; new kinds `qd`, `qdx`, `qj`, `qjx`.
