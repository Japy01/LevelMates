# LevelMates

A World of Warcraft: Forever guild addon. See which guildmates are online and where, match quests with them, and ask for a hand with elites.

## What it does

- **Board** (`/lm`): guildmates who also run LevelMates, with level, zone and group state. Click the Lv or Zone header to sort; bind a key under Key Bindings > LevelMates; tick "Near my level" to hide anyone more than 5 levels away. Right-click a row to invite, whisper or set a waypoint.
- **Quest matching**: when you accept a quest, a line tells you which guildmate on your map has it too. With Questie installed it also says who could pick it up.
- **Help requests**: "Ask for help" tells guildmates what you need. They get a notice and a map waypoint, and an "On my way" button that whispers you.

## Privacy

By default it shares only your **level, zone, class and whether you are in a group**, every 30 seconds and only when something changed. Your **position**, **quest ids** and **XP per hour** are shared only if you turn them on in `/lm options`. Turning "Appear on the board" off stops everything: you send nothing and see nobody.

## Policy

Addon messages only, to your own guild. No combat data, ever. Inviting, whispering and chatting happen only when you click a button, never on their own. Messages are small, validated and rate-limited, and nothing is sent while the game restricts addon chat.

## Install

Copy the `LevelMates` folder into `Interface/AddOns` of your WoW Forever install and restart the game. Everyone who wants to be on the board needs the addon.

## Commands

`/lm` (board), `/lm help <text>`, `/lm cancel`, `/lm options`, `/lm debug`. To try it alone: `/lm sim` (fake guildmates, local only), `/lm sim help`, `/lm sim off`.

## Not in v1 (planned)

"Still needs" quest notices, a named map marker for help requests (v1 uses your map's user waypoint, which replaces your own pin), and ending a help request when the asker groups with a helper.

License: MIT.

---

# LevelMates (es)

Addon de hermandad para World of Warcraft: Forever. Ve qué hermanos están conectados y dónde, empareja misiones con ellos y pide ayuda con los elites.

## Qué hace

- **Tablón** (`/lm`): los hermanos que también usan LevelMates, con nivel, zona y estado de grupo. Clic derecho en una fila para invitar, susurrar o poner un punto de ruta.
- **Emparejar misiones**: al aceptar una misión, una línea te dice qué hermano de tu mapa también la tiene. Con Questie instalado dice además quién podría cogerla.
- **Pedir ayuda**: "Pedir ayuda" cuenta a la hermandad con qué necesitas ayuda. Reciben un aviso y un punto en el mapa, y un botón "Voy" que te susurra.

## Privacidad

Por defecto comparte solo tu **nivel, zona, clase y si estás en grupo**, cada 30 segundos y solo cuando algo cambia. Tu **posición**, tus **misiones** y tu **XP por hora** se comparten solo si lo activas en `/lm opciones`. Si apagas "Aparecer en el tablón", se detiene todo: no envías nada y no ves a nadie.

## Política

Solo mensajes de addon, a tu propia hermandad. Nada de combate, nunca. Invitar, susurrar y escribir en el chat ocurre solo cuando pulsas un botón, nunca por su cuenta. Los mensajes son pequeños, validados y con límite de ritmo, y no se envía nada mientras el juego restringe el chat de addons.

## Instalación

Copia la carpeta `LevelMates` en `Interface/AddOns` de tu instalación de WoW Forever y reinicia el juego. Todos los que quieran salir en el tablón necesitan el addon.

## Comandos

`/lm` (tablón), `/lm ayuda <texto>`, `/lm cancelar`, `/lm opciones`, `/lm debug`. Para probarlo solo: `/lm sim` (hermanos falsos, solo en local), `/lm sim help`, `/lm sim off`.

## Pendiente para después de v1

Aviso "le falta" de misiones, marcador con nombre en el mapa para las peticiones de ayuda (v1 usa el punto de ruta del jugador, que sustituye al tuyo), y cerrar la petición cuando el que pide entra en grupo con quien dijo "Voy".

Licencia: MIT.
