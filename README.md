# LevelMates

A World of Warcraft: Forever guild addon. See which guildmates are online and where, match quests with them, and ask for a hand with elites.

## What it does

- **Board** (`/lm`): guildmates who also run LevelMates, with level, zone and group state. Click the Lv or Zone header to sort; bind a key under Key Bindings > LevelMates, or use the minimap button (drag to move, right-click for options); tick "Near my level" to hide anyone more than 5 levels away. Right-click a row to invite, whisper or set a waypoint.
- **Quest matching**: when you accept a quest, a line tells you which guildmate on your map has it too. With Questie installed it also says who could pick it up.
- **Help requests**: "Ask for help" tells guildmates what you need. They get a notice and a map waypoint, and an "On my way" button that whispers you.
- **Dungeon groups** (Dungeons tab, or `/lm lfg`): post "Find a group" with a dungeon, your role and a short note; guildmates see it in the list and get a chat line if it fits their level. Ads last 20 minutes.
- **Leveling partner** (Guildmates tab): tick "Looking for a partner"; guildmates within 3 levels who also tick it appear at the top, tinted, with a chat line. It turns itself off when you group with one of them.
- **Rested XP**: yours next to the board heading, with a chat line when it reaches the maximum; guildmates who opt in ("Share my rested XP", off by default) show theirs when you hover their name.
- **Journal** (Journal tab, or `/lm diario`): a private record of your leveling — level-ups with the time each took, quests, dungeons with the guildmates who came, groups with guildmates, green-or-better items, profession milestones and deaths. Filter by type, search, pages, and a clear button. Nothing is sent to anyone.
- **Guild goals** (Goals tab, or `/lm metas`): officers set goals for the guild — everyone to a level, a dungeon together, or a counter of levels, quests or dungeons between everyone — with live progress and who is missing. Kept across sessions; up to 5 at a time. Anyone can also set a personal goal ("My goal": a level by a date) that the guild sees.
- **Wishlist** (Wishes tab, or `/lm deseos`): up to 10 items you want, added with Shift+click; guildmates see them, item tooltips say who wants an item, and looting something a guildmate wants tells you who to pass it to.
- **Copy for Discord** ("Discord" button on the board): the current tab as ready-to-paste Discord text (Ctrl+C, Ctrl+V). Nothing is sent anywhere.
- **Professions** (Professions tab, or `/lm oficios`): who has each profession and at what rank (sharing can be turned off).
- **Guild wall** (Wall tab, or `/lm muro`): level-ups, dungeons with guildmates, rare loot and goals of the last 7 days; what you missed arrives when you log in.
- **Giveaways** on the Wishes tab ("Give away"): matched with wishes both ways, and a guildmate can reserve one.
- **Meetups** on dungeon cards ("Meet here..."): a day and time, joined with a role, with a reminder 15 minutes before.
- **Join a group** from a dungeon card ("Join Mario as healer"); the poster is told and sees who joined, with an invite button for each.
- **Notices**: important ones also in the middle of the screen; a [Congratulate] link when a guildmate levels up; a notice when a guildmate has a newer LevelMates. The Journal tab shows your pace (time per level, fastest level, rough time to 60).

## Privacy

By default it shares only your **level, zone, class and whether you are in a group**, every 30 seconds and only when something changed. Your **position**, **quest ids**, **XP per hour** and **rested XP** are shared only if you turn them on in `/lm options`. Turning "Appear on the board" off stops everything: you send nothing and see nobody.

## Policy

Addon messages only, to your own guild. No combat data, ever. Inviting, whispering and chatting happen only when you click a button, never on their own. Messages are small, validated and rate-limited, and nothing is sent while the game restricts addon chat.

## Install

Copy the `LevelMates` folder into `Interface/AddOns` of your WoW Forever install and restart the game. Everyone who wants to be on the board needs the addon.

## Commands

`/lm` (board), `/lm lfg` (Dungeons tab), `/lm diario` (Journal tab), `/lm metas` (Goals tab), `/lm deseos` (Wishes tab), `/lm oficios` (Professions tab), `/lm muro` (Wall tab), `/lm help <text>`, `/lm cancel`, `/lm options`, `/lm debug`. To try it alone: `/lm sim` (fake guildmates, local only), `/lm sim help`, `/lm sim lfg`, `/lm sim pal`, `/lm sim rested`, `/lm sim diario`, `/lm sim metas`, `/lm sim deseos`, `/lm sim oficios`, `/lm sim nivel`, `/lm sim muro`, `/lm sim mercadillo`, `/lm sim quedada`, `/lm sim off`.

## Not in v1 (planned)

"Still needs" quest notices, a named map marker for help requests (v1 uses your map's user waypoint, which replaces your own pin).

License: MIT.

---

# LevelMates (es)

Addon de hermandad para World of Warcraft: Forever. Ve qué hermanos están conectados y dónde, empareja misiones con ellos y pide ayuda con los elites.

## Qué hace

- **Tablón** (`/lm`): los hermanos que también usan LevelMates, con nivel, zona y estado de grupo. Clic derecho en una fila para invitar, susurrar o poner un punto de ruta.
- **Emparejar misiones**: al aceptar una misión, una línea te dice qué hermano de tu mapa también la tiene. Con Questie instalado dice además quién podría cogerla.
- **Pedir ayuda**: "Pedir ayuda" cuenta a la hermandad con qué necesitas ayuda. Reciben un aviso y un punto en el mapa, y un botón "Voy" que te susurra.
- **Grupos de mazmorra** (pestaña Mazmorras, o `/lm lfg`): publica "Buscar grupo" con una mazmorra, tu rol y una nota corta; los hermanos lo ven en la lista y reciben una línea en el chat si encaja con su nivel. Los anuncios duran 20 minutos.
- **Compañero de leveo** (pestaña Hermanos): marca "Busco compañero"; los hermanos a 3 niveles o menos que también lo marcan salen arriba, resaltados, con una línea en el chat. Se desmarca solo al agruparte con uno de ellos.
- **XP descansada**: la tuya junto al título del tablón, con una línea en el chat cuando llega al máximo; los hermanos que lo activan ("Compartir mi XP descansada", apagado por defecto) muestran la suya al pasar el ratón por su nombre.
- **Diario** (pestaña Diario, o `/lm diario`): un registro privado de tu subida — niveles con lo que tardaste en cada uno, misiones, mazmorras con los hermanos que fueron, grupos con hermanos, objetos verdes o mejores, hitos de profesiones y muertes. Filtro por tipo, búsqueda, páginas y botón para borrarlo. No se envía nada a nadie.
- **Metas de hermandad** (pestaña Metas, o `/lm metas`): los oficiales marcan objetivos para la hermandad — todos a un nivel, una mazmorra juntos, o un contador de niveles, misiones o mazmorras entre todos — con el progreso en directo y quién falta. Se guardan entre sesiones; hasta 5 a la vez. Cualquiera puede poner además su meta personal ("Mi meta": un nivel para una fecha) y la hermandad la ve.
- **Lista de deseos** (pestaña Deseos, o `/lm deseos`): hasta 10 objetos que quieres, añadidos con Mayús+clic; la hermandad los ve, el tooltip de un objeto dice quién lo quiere y, si te cae algo que quiere un hermano, te avisa para que se lo pases.
- **Copiar para Discord** (botón "Discord" del tablón): la pestaña actual como texto listo para pegar en Discord (Ctrl+C, Ctrl+V). No se envía nada a ningún sitio.
- **Oficios** (pestaña Oficios, o `/lm oficios`): quién tiene cada profesión y a qué nivel (se puede dejar de compartir).
- **Muro de la hermandad** (pestaña Muro, o `/lm muro`): subidas de nivel, mazmorras con hermanos, botín raro y metas de los últimos 7 días; lo que te perdiste llega al entrar.
- **Mercadillo** en la pestaña Deseos ("Regalar"): se cruza con los deseos en los dos sentidos y un hermano puede reservar un regalo.
- **Quedadas** en las tarjetas de mazmorra ("Quedar aquí..."): día y hora, apuntarse con un rol y recordatorio 15 minutos antes.
- **Apuntarse a un grupo** desde la tarjeta de la mazmorra ("Me apunto con Mario como sanador"); quien lo publicó recibe el aviso, ve los apuntados y puede invitarlos con un clic.
- **Avisos**: los importantes también en el centro de la pantalla; un enlace [Felicitar] cuando un hermano sube de nivel; aviso cuando un hermano tiene una versión más nueva. La pestaña Diario muestra tu ritmo (tiempo por nivel, el nivel más rápido y una estimación hasta 60).

## Privacidad

Por defecto comparte solo tu **nivel, zona, clase y si estás en grupo**, cada 30 segundos y solo cuando algo cambia. Tu **posición**, tus **misiones**, tu **XP por hora** y tu **XP descansada** se comparten solo si lo activas en `/lm opciones`. Si apagas "Aparecer en el tablón", se detiene todo: no envías nada y no ves a nadie.

## Política

Solo mensajes de addon, a tu propia hermandad. Nada de combate, nunca. Invitar, susurrar y escribir en el chat ocurre solo cuando pulsas un botón, nunca por su cuenta. Los mensajes son pequeños, validados y con límite de ritmo, y no se envía nada mientras el juego restringe el chat de addons.

## Instalación

Copia la carpeta `LevelMates` en `Interface/AddOns` de tu instalación de WoW Forever y reinicia el juego. Todos los que quieran salir en el tablón necesitan el addon.

## Comandos

`/lm` (tablón), `/lm lfg` (pestaña Mazmorras), `/lm diario` (pestaña Diario), `/lm metas` (pestaña Metas), `/lm deseos` (pestaña Deseos), `/lm oficios` (pestaña Oficios), `/lm muro` (pestaña Muro), `/lm ayuda <texto>`, `/lm cancelar`, `/lm opciones`, `/lm debug`. Para probarlo solo: `/lm sim` (hermanos falsos, solo en local), `/lm sim help`, `/lm sim lfg`, `/lm sim pal`, `/lm sim rested`, `/lm sim diario`, `/lm sim metas`, `/lm sim deseos`, `/lm sim oficios`, `/lm sim nivel`, `/lm sim muro`, `/lm sim mercadillo`, `/lm sim quedada`, `/lm sim off`.

## Pendiente para después de v1

Aviso "le falta" de misiones, marcador con nombre en el mapa para las peticiones de ayuda (v1 usa el punto de ruta del jugador, que sustituye al tuyo).

Licencia: MIT.
