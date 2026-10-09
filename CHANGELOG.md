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
- Board look: window height follows the list, title shows the count, the sorted header shows its direction, group and level are colour-coded, striped rows with hover highlight, and the filter checkbox is now visible.
