# Changelog

## 0.5.7

- **Book size**: Options (normal, big, very big), `/lm tamaño 80-150`, and - / + buttons by the close button.
- **Guildmates** lists who was seen today though offline now (grey, with when); when nobody else has the addon, the invite to copy is right there.
- **Home**: bigger panel headings; the four numbers with the icon on the left and one thing each; the wall writes two lines per entry with a short time; Now shows the trainer's spells one per line with icons; the invite lives in Who is where; my panel sums up achievements, guild firsts and my goal; no rested text beside the heading.

## 0.5.6

- **Fixed: an empty Home, Members and guild history for guild members** (not the guild master). Forever hands them the guild list as a secret value; the addon now reads the classic roster instead and skips what it cannot read.
- Hardened against secret values and protected calls everywhere: officer check, who is online, inspect, invites, talents, recipes, bags, chat sends. A hidden value is "unknown", never an error or a wrong yes.

## 0.5.4

- When the game blocks an action of the addon, the chat says so and `/lm informe` lists which action, when and with which version. Copy that text to whoever helps.

## 0.5.3

- **The addon is now called Forever Guild** (it was LevelMates, then Guild Companion for a day). `/foreverguild` opens it; `/lm` and `/guildcompanion` still work. Nothing is lost when updating.

## 0.5.2

- **LevelMates is now Guild Companion.** The new name shows in the addon list, the book, chat and Discord lines; `/guildcompanion` opens it too. Its folder and saved data keep the old name, so updating loses nothing, and old and new versions still talk to each other.

## 0.5.1

- **Talent viewer fixed**: every talent now sits in its own branch (on Forever a talent belongs to several groups, and most ended up nowhere). Trees shared by 0.5.0 are dropped and asked for again.
- **View build** in a member's menu (Guild > Members), for any class.
- `/lm talentos` says what LevelMates reads of your tree and build.

## 0.5.0

- **Fixed: "LevelMates has been blocked from an action"** when changing talents. The build code is now made from the talent API; the game's talent window is never asked.
- **Talent viewer** (View build, on cards and the Class tab): a guildmate's build drawn on their class tree, as the game's window: a panel per branch with its points, talents on a grid with the game's own art (full, partial, open, locked), arrows, spell tooltips. Each player shares their class tree once a week; a missing tree is asked for. The game's link is still one click away.
- **Class tab**: branch names (Arms, Fury…) where Forever only says "Tree 1".
- **Guild firsts**: the first to reach level 10, 20… 60 and 300 in each profession, by the server's clock; the same second is shared. Listed in Journal > Achievements.
- **Inspect**: the Gear window of your target or a group member, even without LevelMates. The window says how old its data is and where it came from (shared, inspected), in orange after three days.
- **Gear window**: out of sight, the class crest instead of an empty model (Forever cannot dress a model by race). Items with a random suffix ("of the Bear") show their right name and stats.
- **Market**: bound and quest items can no longer be offered.
- **Recipes**: a crafter's recipes by kind, level and name, with headings; "Tradable only"; "Who else crafts it?". Wrong recipe data cleans itself (professions someone no longer has, ranks a level can't have, a window that was not yours).

## 0.4.0

- **A tag for a Discord bot** (Options > Share, off by default): Discord lines start with [LM1 ...] so a bot can keep a sign-up board; format in docs/discord-tag.md. Now groups announced in Discord post their joins, leaves and withdrawal too.
- **Groups, one idea for everything**: a group is what (a dungeon, a raid, a battleground, world PvP or anything you name), when (**Now** or a day and hour), its size and places per role. Looking for people now and planning for later look the same, with the same cards: five places as slots, bigger groups as counters per role.
- **The Groups section** (was Dungeons): Now, today and tomorrow, later this week and the chat's group ads, beside the **Create a group** form; and the **Catalogue** of dungeons, raids and PvP.
- **Raids and PvP**: Molten Core, Onyxia, Zul'Gurub, Blackwing Lair, Ahn'Qiraj, Naxxramas or a raid with your own name (10, 20 or 40, with the places per role the leader sets); Warsong Gulch, Arathi Basin, Alterac Valley and world PvP; or "Other" with any name.
- **An activity's panel**, rebuilt: its groups as cards, my run's places to manage, guildmates of its level, chat ads, and "Create a group here".
- **Home** shows the groups: Now first, yours included, then the next ones.
- **The book as a dashboard**: a wider book (900); **Home** shows four numbers (guild level, online, your item level, the weekly challenge), the message of the day, your character (XP with rested, gear in miniature, role, points of the week), what is happening now, the next two runs with their five slots, quest posts, who is where and today on the wall. Each box says what to do when empty.
- **Pills** by the title: guildmates online (a click opens Guildmates), Discord linked, how many still run 0.3.
- **"Are you sure?"** before cancelling a run, withdrawing a quest post, deleting a goal, removing a wish or an offer, or taking someone out of your run.
- **Runs** (Groups): today's and tomorrow's runs as cards with their slots and buttons, the rest of the week below, and a **Create a run** form beside them.
- **Notices tray**: the last notices with Go to their tab; the minimap button counts the unread (Shift+click opens them); a strip under the minimap shows the newest for 10 seconds, after combat.
- **Level bar** (off by default, `/lm barra`): XP per hour, time to level, time in the level, kills. **Banner** when you level up.
- What a click did shows **at the foot of the book** while it is open (6 seconds, a click closes it); notices and links still go to chat.
- **Armory**: your gear is shared (with its switch); a guildmate's card shows their item level, counted right, and a Gear window with their paper doll and model; cards show builds of every class.
- **Members** (Guild tab): the whole guild with shared notes, the history of joins, departures and promotions, the alts of each member and the race to 60; the officers' own message of the day at the top of Home.
- **Bank** (Guild tab): whoever opens the guild bank shares what is in it.
- **Recipes**: yours are read from your own profession window and shared; search an item on the Professions tab to see who crafts it and ask them; browse someone's recipes; item tooltips name crafters; a hint when a rank is full and it is time to train.
- **Quest board**: Alt+click a quest in your log to look for people for it; guildmates say "Me too"; a Quests view with filters, and a notice when someone looks for a quest you have. Together lists group quests in common.
- **Map**: pins on continents too, the same size at any zoom, bundled when crowded, a click to route there, fresh positions when the map opens, old pins gone after five minutes; optional names on the pins.
- **Runs**: meetups have five slots (1 tank, 1 healer, 3 damage) and a leader who keeps the official line-up; late joins for a full role wait, the leader adds or removes by hand, and **Invite all** invites the run.
- **My role** (tank, healer, damage), shared; guessed from the class when unset.
- **Together**: groups you could make right now from who is online, by level and role.
- **Discord**: runs announced in the guild's Discord channel through the game's own guild link, from clicks only (each player needs their Discord account linked; otherwise "Copy for Discord").
- **New sync.** Meetups and who joins them, the guild wall, class questions and market offers are kept by everyone and handed to whoever logs in later, even when their author is offline. Removed things stay removed.
- What you do inside a dungeon (cancelling a meetup, a wall entry) goes out when you leave instead of being lost; help requests and groups go first.
- The book redraws at most twice a second, and only when something really changed.
- Characters with a surname ("Name Surname") are recognised as themselves: your own card, ads and meetups.
- Achievements count your real journal; long Mates and calendar lists have pages.
- `/lm debug` and `/lm informe` show the message queue, the records kept and guildmates still on an old version.
- **Clean cut:** 0.4.0 and 0.3.x no longer see each other. Guildmates on 0.3.x get the game's "newer version" notice, and their card says so.

## 0.3.2

- **Quiet mode** (Options > Notices): only help requests, groups and goals; the other notices, the screen messages and the sound go off, and come back as they were.
- Bars grow smoothly when their value changes.
- **Route** (card, right-click menu, rare sightings): the pin is followed on screen and the chat says where it points, or why the map does not allow it.
- The small windows (card, dungeon panel, wishes, goals, groups, meetups, Discord) are pages of the book too, written in ink.

## 0.3.1

- Home: an icon for every kind of row; the Guild tab and the challenge achievement show your faction's banner.
- The group XP window can be minimised or closed (`/lm xp` brings it back).
- Guild points: the week turns at the realm's Monday midnight; points belong to each guild (a new guild starts from zero); nothing is sent while sharing is off; helps count at most twice a day per person asking.
- **Dungeon panel**: a click on a dungeon card opens its panel next to the book: the guild's groups with who joined and their role, ads from chat, meetups, guildmates of its levels online, with buttons to join, leave, whisper, invite, look for a group or set up a meetup. Right-click keeps the quick menu.
- **Options in three pages**: General, Share and Notices.
- Inviting says so at once in chat (the server can take a few seconds to deliver it).
- **Achievements**: twenty personal milestones with the game's icons (levels, dungeons with guildmates, helps, gifts, meetups, quests, a weekly challenge, and one for the cemetery's regulars). Earned ones go to the guild wall and show on your card; the Journal tab lists them all with their progress. Counted from your journal too, so you do not start from zero.
- `/lm informe` opens a report to copy when something goes wrong: versions, messages, guildmates seen and LevelMates' last errors. Nothing is sent.

## 0.3.0

- **The guild book**: LevelMates looks like the game's spellbook: the game's own frame with a round portrait, icon tabs at the top, a parchment page with the game's decorative letters, ribbon and divider, section bands with counts, and dark ink on the page.
- **Five tabs instead of nine**: Home, Guildmates, Dungeons, Guild (with Wall, Goals, Market, Professions, Class and, for officers, Recruit) and Journal. Old commands (`/lm metas`, `/lm oficios`…) still open their page.
- **Home**: the board opens on what to do now: the guild level and the weekly challenge, help requests, open groups and today's meetups, guildmates near your level or in your zone, gifts on your wishlist, spells at your trainer, this week's top three, and an invite to copy when nobody is around yet.
- **Guild progress**: what you do (levels, dungeons with guildmates, quests, helps, gifts, meetups) adds points; the guild levels up together, a weekly challenge rotates, and the top three of the week are shown (never who is last). Option "Share my guild points".
- **Ask for help** never fails in silence: a confirmation when it goes out, and the reason when it cannot (no guild, not now).
- `/lm sim puntos` tries the guild progress alone.
- `/lm tinta 1-5` sets how dark the text on the page is, live.

## 0.2.0

- **Class tab**: talent builds of guildmates of your class (points per branch and level), with "View build", which puts its link in your chat (only you see it) to open in the game's build viewer; a macro library for each class, written for LevelMates with spell names in your language, created with a click; and macros guildmates share ("Share macro", up to 5).
- **Guildmate card**: click a name on the board to see their class, level, zone, build, professions, wishes and giveaways, personal goal, latest on the wall and meetups, with Whisper, Invite, Waypoint and View build.
- **Chat ads on the dungeon cards**: group ads posted in Trade, General and other public channels ("LFM DM need heal", "busco grupo minas") are counted on their dungeon's card ("2 looking · 3 in chat"), shown in its tooltip and can be whispered from its menu. Only read on your computer; option "Read group ads from chat".
- **Group XP bars**: while grouped with guildmates, a small window shows everyone's XP in the level (and rested XP when they share it).
- **Quests they lack**: in a group, a guildmate's card lists your quests they do not have (when they share their quests), with a Share button.
- **Trainer reminder**: leveling up tells you which spells are waiting at your class trainer (known from your last visit); before any visit, a reminder on even levels.
- **Cemetery**: your deaths go to the guild wall (level and zone, nothing from combat), and the wall has a Cemetery button with the week's deaths.
- **Ask your class**: a question to guildmates of your class from the Class tab; they get a notice with [Answer], which opens a whisper. The last day's questions are listed on the tab.
- **Alts**: your other characters in the same guild are shared, shown on your card and in the board tooltip; `/lm alts` shows all your characters there with level and professions.
- **Meetup calendar**: on the Dungeons tab, "Calendar" lists the next 7 days of meetups by day; click to join, leave or cancel.
- **Inactive members** (officers): on the Recruit tab, members away for 14 or 30 days with level, rank, last login and join date (noted by LevelMates from the day it first sees them). It only informs.
- **Guild market**: in the Wishes tab, "Offer" puts an item up for free or for a price in gold; the price shows with the game's coins, and "I'll buy it" tells the seller. Payment and handing over are by trade or mail: the addon never touches gold.
- **Window style**: LevelMates' windows use the game's own frame with a warm brown panel, the character sheet's stripes and plaques, and dungeon cards with the whole picture; `/lm options` has a Classic style too.
- The window is a little wider, for nine tabs.
- `/lm clase` opens the Class tab; `/lm alts` opens your own card; `/lm sim clase`, `/lm sim xp` and `/lm sim muertes` try them alone.

## 0.1.2

- Language option: automatic (the game's), English or Spanish, whatever the game client's language; a change offers to reload the interface.
- Dungeon cards use only the game's own art: Forever's loading screens for Hall of Thanes (Old Ironforge) and Ruins of Lordaeron, the Scarlet Halls screen for the Library. No other addon's files are used.

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
