# LevelMates

A guild companion for leveling together in World of Warcraft: Forever. See which guildmates are online and where, find dungeon groups, set guild goals, share wishlists and professions, and keep up with what happens in the guild.

Everyone who wants to appear needs the addon. English and Spanish: the game's language, or the one you choose in `/lm options`.

## What it does

### Guildmates
- **Board** (`/lm`, the minimap button or a key under Key Bindings → LevelMates): guildmates online with LevelMates, with class, level, zone and group state. Sort by level or zone, filter to players near your level, and right-click a row to invite, whisper or set a waypoint. The busiest zone is shown next to the heading.
- **Leveling partner**: tick "Looking for a partner" and guildmates within 3 levels who also ticked it appear at the top.
- **Quest matching**: when you accept a quest, you are told which guildmate on your map has it too (with Questie: who could pick it up). Grouped with guildmates, their progress on the quests you share shows when you hover their name.
- **Guild map**: guildmates who share their position appear on the world map.
- **Rested XP** next to the heading, with a notice at the maximum.

### Dungeons
- **Dungeons tab**: a card with artwork for each of the 14 dungeons, highlighted when it fits your level, with how many are looking for a group. Click a card to join a group ("Join Mario as healer"), whisper, invite, look for a group there, or set up a **meetup** ("Saturday 21:00", with a reminder 15 minutes before).

### Goals and progress
- **Goals tab**: officers set guild goals (everyone to a level, a dungeon together, a counter of levels, quests or dungeons) with live progress and who is missing. Anyone can set a personal goal.
- **Journal tab**: a private record of your leveling (levels with the time each took, quests, dungeons, groups, good items, professions, deaths) and your pace with a rough time to 60. Nothing in the journal is sent to anyone.
- **Wall tab**: the last 7 days in the guild: level-ups, dungeons with guildmates, rare loot, goals reached. What you missed arrives when you log in.

### Items and professions
- **Wishes tab**: up to 10 items you want, added with Shift+click, and up to 10 you give away. Wishes and giveaways are matched both ways ("Ana gives away [Sword], which is on your list"), a giveaway can be reserved, and item tooltips say who wants or gives an item. Looting something a guildmate wants tells you who to pass it to.
- **Professions tab**: who has each profession and at what rank, grouped by profession.

### Help and notices
- **Ask for help** with an elite: guildmates get a notice and a waypoint, and an "On my way" button. A **panic key** (Key Bindings → LevelMates, or `/lm panico`) asks at once.
- **Rare sightings**: a rare you see is announced to guildmates in that zone, with a [Waypoint] link.
- **Notices** for what matters, also in the middle of the screen; a [Congratulate] link when a guildmate levels up; a notice when a guildmate runs a newer LevelMates.
- **Copy for Discord**: the "Discord" button puts the current tab into a box as ready-to-paste Discord text. Nothing is sent anywhere.

### Officers
- **Recruit tab** (officers and guild master only): three shared templates with placeholders (`{guild}`, `{online}`, `{level}`), posted to channel 2 (Trade) or 1 (General) with a click, a 10-minute wait shared by all officers, and an optional reminder that offers a one-click Post.

## Privacy

Everything goes only to your own guild, as addon messages. In `/lm options` you can turn each part off.

- **Always** (while "Appear on the board" is on): your level, zone, class and group state.
- **On by default**, with a switch to stop: your professions and ranks; your level-ups, dungeons with guildmates, rare loot and personal goal on the guild wall.
- **Only when you use them**: your wishes, giveaways, personal goal, dungeon ads, meetups and the groups you join.
- **Off by default**, only if you turn them on: your position (map, rare sightings), your quests (quest matching and progress), XP per hour and rested XP.

Turning "Appear on the board" off stops everything: you send nothing and see nobody. The journal never leaves your computer.

## Policy

Addon messages only, to your own guild. No combat data, ever. Inviting, whispering, chatting and posting to public channels happen only when you click, never on their own. Messages are small, validated and rate-limited, and nothing is sent while the game restricts addon chat.

## Install

Copy the `LevelMates` folder into `Interface/AddOns` of your WoW Forever install and restart the game.

## Commands

`/lm` (board), `/lm lfg`, `/lm diario`, `/lm metas`, `/lm deseos`, `/lm oficios`, `/lm muro`, `/lm reclutar` (open a tab), `/lm help <text>` (ask for help), `/lm cancel`, `/lm panico`, `/lm options`, `/lm debug`.

To try it alone (fake guildmates, local only, nothing is sent): `/lm sim`, and `/lm sim help`, `lfg`, `pal`, `rested`, `diario`, `metas`, `deseos`, `oficios`, `nivel`, `muro`, `mercadillo`, `quedada`, `raro`; `/lm sim off` clears them.

Made by Diego (Japy01) with the help of AI (Claude, by Anthropic).

License: MIT.

---

# LevelMates (es)

Un compañero de hermandad para subir de nivel juntos en World of Warcraft: Forever. Ve qué hermanos están conectados y dónde, encuentra grupo para mazmorras, marca metas de hermandad, comparte listas de deseos y profesiones, y entérate de lo que pasa en la hermandad.

Todos los que quieran salir necesitan el addon. En español e inglés: el idioma del juego, o el que elijas en `/lm opciones`.

## Qué hace

### Hermanos
- **Tablón** (`/lm`, el botón del minimapa o una tecla en Atajos de teclado → LevelMates): los hermanos conectados con LevelMates, con clase, nivel, zona y si están en grupo. Ordena por nivel o zona, filtra a los de tu nivel y haz clic derecho en una fila para invitar, susurrar o poner un punto de ruta. Junto al título sale la zona con más hermanos.
- **Compañero de subida**: marca "Busco compañero" y los hermanos a 3 niveles o menos que también lo marcan salen arriba.
- **Misiones**: al aceptar una misión te dice qué hermano de tu mapa también la tiene (con Questie, quién podría cogerla). En grupo con hermanos, su progreso en las misiones que compartís sale al pasar el ratón por su nombre.
- **Mapa de la hermandad**: los hermanos que comparten su posición salen en el mapa del mundo.
- **XP descansada** junto al título, con aviso al llegar al máximo.

### Mazmorras
- **Pestaña Mazmorras**: una tarjeta con imagen para cada una de las 14 mazmorras, resaltada si es de tu nivel, con cuántos buscan grupo. Clic en una tarjeta para apuntarte a un grupo ("Me apunto con Mario como sanador"), susurrar, invitar, buscar grupo ahí o crear una **quedada** ("sábado 21:00", con recordatorio 15 minutos antes).

### Metas y progreso
- **Pestaña Metas**: los oficiales marcan metas de hermandad (todos a un nivel, una mazmorra juntos, un contador de niveles, misiones o mazmorras) con el progreso en directo y quién falta. Cualquiera puede ponerse una meta personal.
- **Pestaña Diario**: un registro privado de tu subida (niveles con lo que tardaste en cada uno, misiones, mazmorras, grupos, objetos buenos, profesiones, muertes) y tu ritmo con una estimación hasta 60. Nada del diario se envía a nadie.
- **Pestaña Muro**: los últimos 7 días de la hermandad: subidas de nivel, mazmorras con hermanos, botín raro, metas cumplidas. Lo que te perdiste llega al entrar.

### Objetos y profesiones
- **Pestaña Deseos**: hasta 10 objetos que quieres, añadidos con Mayús+clic, y hasta 10 que regalas. Deseos y regalos se cruzan en los dos sentidos ("Ana regala [Espada], que está en tu lista"), un regalo se puede reservar, y el tooltip de un objeto dice quién lo quiere o lo regala. Si te cae algo que quiere un hermano, te avisa para que se lo pases.
- **Pestaña Oficios**: quién tiene cada profesión y a qué nivel, agrupado por profesión.

### Ayuda y avisos
- **Pedir ayuda** con un élite: los hermanos reciben un aviso y un punto de ruta, y un botón "Voy". Un **botón de pánico** (Atajos de teclado → LevelMates, o `/lm panico`) la pide al momento.
- **Avistamiento de raros**: un raro que ves se avisa a los hermanos de esa zona, con un enlace [Ruta].
- **Avisos** de lo importante, también en el centro de la pantalla; un enlace [Felicitar] cuando un hermano sube de nivel; aviso cuando un hermano tiene una versión más nueva de LevelMates.
- **Copiar para Discord**: el botón "Discord" pone la pestaña actual en un cuadro como texto listo para pegar en Discord. No se envía nada a ningún sitio.

### Oficiales
- **Pestaña Reclutar** (solo oficiales y maestro): tres plantillas compartidas con comodines (`{hermandad}`, `{conectados}`, `{nivel}`), publicadas en el canal 2 (Comercio) o 1 (General) con un clic, una espera de 10 minutos compartida entre oficiales y un recordatorio opcional que ofrece Publicar con un clic.

## Privacidad

Todo va solo a tu hermandad, como mensajes de addon. En `/lm opciones` puedes apagar cada parte.

- **Siempre** (mientras "Aparecer en el tablón" esté activado): tu nivel, zona, clase y si estás en grupo.
- **Activado por defecto**, con un interruptor para dejar de hacerlo: tus profesiones y su nivel; tus subidas de nivel, mazmorras con hermanos, botín raro y meta personal en el muro.
- **Solo cuando los usas**: tus deseos, regalos, meta personal, anuncios de mazmorra, quedadas y los grupos a los que te apuntas.
- **Apagado por defecto**, solo si lo activas: tu posición (mapa, avistamiento de raros), tus misiones (emparejar misiones y su progreso), la XP por hora y la XP descansada.

Si apagas "Aparecer en el tablón", se detiene todo: no envías nada y no ves a nadie. El diario nunca sale de tu ordenador.

## Política

Solo mensajes de addon, a tu propia hermandad. Nada de combate, nunca. Invitar, susurrar, escribir en el chat y publicar en canales públicos ocurre solo cuando haces clic, nunca por su cuenta. Los mensajes son pequeños, validados y con límite de ritmo, y no se envía nada mientras el juego restringe el chat de addons.

## Instalación

Copia la carpeta `LevelMates` en `Interface/AddOns` de tu instalación de WoW Forever y reinicia el juego.

## Comandos

`/lm` (tablón), `/lm lfg`, `/lm diario`, `/lm metas`, `/lm deseos`, `/lm oficios`, `/lm muro`, `/lm reclutar` (abren una pestaña), `/lm ayuda <texto>` (pedir ayuda), `/lm cancelar`, `/lm panico`, `/lm opciones`, `/lm debug`.

Para probarlo solo (hermanos falsos, solo en local, no se envía nada): `/lm sim`, y `/lm sim help`, `lfg`, `pal`, `rested`, `diario`, `metas`, `deseos`, `oficios`, `nivel`, `muro`, `mercadillo`, `quedada`, `raro`; `/lm sim off` los quita.

Hecho por Diego (Japy01) con ayuda de IA (Claude, de Anthropic).

Licencia: MIT.
