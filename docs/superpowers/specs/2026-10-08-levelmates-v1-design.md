# LevelMates v1: addon de hermandad para la fase de leveo en WoW Forever

Fecha: 2026-10-08. Estado: diseño aprobado en conversación; pendiente del spike de transporte (§4.1).

## 1. Objetivo

Que los miembros de una hermandad que suben de nivel a la vez se encuentren: quién está conectado y
dónde, quién comparte misión contigo, y quién necesita una mano con un elite. Sin programa externo,
sin red, sin tocar el combate. Publicado para cualquier hermandad en CurseForge y Wago, en inglés y
español, configurable sin tocar código.

Primeros usuarios: la hermandad de Diego y Mario en WoW Forever (cliente 1.60.x, interfaz 16001).

## 2. Cumplimiento de la política de Blizzard (requisito de diseño, no de redacción)

| Regla | Cómo la cumple el diseño |
|---|---|
| Gratis, sin versión premium | MIT en GitHub; sin ninguna función de pago |
| Código visible | Lua legible, sin minificar ni ofuscar; sin binarios |
| Sin impacto en los reinos | Un latido por jugador cada 30 s y solo si cambió; cola con límite de ritmo (ChatThrottleLib embebida o equivalente propio con el mismo presupuesto: ~800 bytes/s en ráfaga, 1 KB/s sostenido); mensajes ≤ 255 bytes |
| Sin publicidad ni donaciones | Nada en el juego; en CurseForge, como mucho un enlace al repo |
| Contenido apto | Solo texto del propio jugador en el nombre del objetivo de ayuda, limitado a 60 caracteres y sin enlaces |
| EULA y cambios de 2026 | No lee eventos de combate; no envía nada mientras `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()` sea verdadero (encuentros, piedras angulares, PvP); lo encola |
| No actúa por el jugador | Invitar, susurrar, compartir misión y escribir en chat salen solo de un clic (Forever lo exige además: `SendChatMessage` sin clic se descarta) |
| Blizzard puede desactivarlo | Nada que ocultar; `/levelmates off` apaga todo |

Precedentes publicados en CurseForge que funcionan en Forever con mensajes de addon: WoWForeverRace
(canal oculto temporal, realm-wide), guildos (hermandad).

## 3. Alcance de v1

Dentro: tablón, emparejar misiones, pedir ayuda; página de Opciones; inglés y español; integración
opcional con Questie para posiciones de misión; publicación.

Fuera (v2 en adelante): busco grupo de mazmorra, compañero de leveo, tablón de equipo, metas de
hermandad, guía por zona, XP descansada, diario, Discord. Nada de combate, nunca.

## 4. Transporte

### 4.1 Canal (spike pendiente)

`spike/LM_CommTest` decide, esta noche con dos personajes de la hermandad:

- Si `C_ChatInfo.SendAddonMessage(prefix, msg, "GUILD")` llega desde un temporizador: **GUILD** es
  el canal. Es lo deseable: solo lo recibe la hermandad, sin unirse a nada.
- Si no llega, **canal temporal oculto** con `JoinTemporaryChannel("LM" .. hash)`, donde `hash` son
  8 caracteres hex de la cadena `reino .. "|" .. nombre de hermandad` (FNV-1a); el canal no se añade a
  ninguna ventana de chat. Lo que llegue de un personaje que no esté en mi roster de hermandad se
  descarta (el roster es la lista blanca). Es el camino probado por WoWForeverRace.
- PARTY/RAID se usan además para lo que solo concierne al grupo (emparejar misiones dentro del
  grupo), si el spike confirma que funcionan.

El módulo `Comm.lua` expone `Comm.Send(kind, fields)` y `Comm.On(kind, handler)`; nadie más sabe
qué canal hay debajo.

### 4.2 Formato de mensaje

Prefijo registrado `LVLM`. Texto: `v1<US>kind<US>campo=valor;campo=valor`, US = `\031`, valores
con `%`, `;`, `=` y bytes < 0x20 codificados `%XX`. Un mensaje nunca supera 255 bytes; lo que no
cabe (lista de misiones larga) se parte en varios mensajes `kind=q` con índice. Versión `v1` fija:
un receptor ignora versiones que no conoce.

| kind | Cuándo | Campos |
|---|---|---|
| `hb` (latido) | cada 30 s si cambió algo, y al entrar al mundo | `l` nivel, `z` id de mapa, `g` 0/1 en grupo, `s` 0/1 hueco en grupo, `x`,`y` posición en centésimas (solo con el interruptor de posición), `r` XP/h (solo con su interruptor), `c` clase, `v` versión del addon |
| `q` | cuando cambia el registro de misiones, si "compartir misiones" está activo | `i` índice/total, `ids` ids de misión separados por `,` (solo en curso, no completadas) |
| `help` | el jugador pulsa Pedir ayuda | `t` objetivo (≤ 60 chars, sin `|`), `z`, `x`, `y`, `id` identificador del aviso |
| `helpok` | cancela o alguien llega | `id` |
| `bye` | al salir | ninguno |
| `ping` | al entrar al mundo | ninguno; los demás responden con su `hb` escalonado 0-5 s |

Lo recibido se valida campo a campo (tipos, rangos, longitud); un mensaje mal formado se ignora
en silencio y se cuenta en `/levelmates debug`.

### 4.3 Cola y bloqueos

`Comm.Send` encola; un ticker de 0,2 s envía mientras haya presupuesto y la comunicación no esté
restringida. En restricción (encuentro, piedra angular, PvP), la cola espera; los `hb` repetidos se
compactan (solo queda el último). Nada se envía dentro de instancias salvo `help`/`helpok`.

## 5. Estado

`Roster.lua`: tabla `mates[nombre] = { level, mapId, inGroup, hasSlot, x, y, xph, class, quests = {ids}, seenAt, version }`.
Un compañero caduca a los 120 s sin latido; `bye` lo quita al momento. Al entrar al mundo se manda
`ping` y los demás responden con su latido escalonado para no saturar.

Las misiones propias se leen de `C_QuestLog` al cambiar (`QUEST_LOG_UPDATE`, con antirrebote de 2 s);
solo ids. Quién "puede coger" una misión: la tiene en el registro o Questie dice que está disponible
para su nivel (si Questie está).

## 6. Funciones

### 6.1 Tablón
Ventana movible con la lista de compañeros conectados con el addon: nombre (color de clase), nivel,
zona, grupo/hueco, y si lo comparte, XP/h. Ordenable por nivel y zona; filtro "cerca de mi nivel"
(±5). Clic derecho: Invitar, Susurrar, Ver en el mapa (si comparte posición). Se abre con
`/levelmates`, el icono del minimapa (opcional) y una tecla asignable.

### 6.2 Emparejar misiones
Al aceptar una misión (`QUEST_ACCEPTED`): si algún compañero de mi mapa la tiene o puede cogerla,
una línea en el tablón y un aviso discreto: "Mario también tiene Mortacechadores (a 200 m)" con botón
Invitar. Al seleccionar una misión completa de grupo en el registro: "A Mario le falta esta". Solo
entre compañeros con "compartir misiones" activo; nunca se comparte con quien no quiere.

### 6.3 Pedir ayuda
Botón en el tablón y comando `/levelmates ayuda <texto>`. Envía `help` con mi posición (aunque no
comparta posición en el latido: pedir ayuda implica decir dónde estás; se avisa en el tooltip).
Los demás ven un aviso, un marcador en el mapa del mundo y en el minimapa con el nombre del que
pide y el objetivo, y pueden pulsar "Voy", que le susurra (con clic) "Voy: Diego". El aviso caduca a
los 10 minutos, al cancelarlo, o cuando el que pide entra en grupo con alguien que pulsó "Voy".

## 7. Opciones y privacidad

Página en Opciones del juego (`Settings.RegisterVerticalLayoutCategory`, con respaldo de ventana
propia si la API falta, como en el proyecto anterior). Por defecto, solo nivel y zona.

| Opción | Por defecto |
|---|---|
| Aparecer en el tablón (enviar latidos) | activado |
| Compartir mi posición | desactivado |
| Compartir mis misiones | desactivado |
| Compartir XP por hora | desactivado |
| Avisos de misiones compartidas | activado |
| Recibir peticiones de ayuda | activado |
| Sonido en avisos | activado |
| Icono del minimapa | activado |
| Idioma | el del cliente |

Todo guardado por cuenta (`LevelMatesDB`) con una sección por personaje para la posición de la ventana.

## 8. Idiomas

`Locales/enUS.lua` (base, completa) y `Locales/esES.lua`; tabla `L` con `setmetatable` que devuelve la
clave inglesa si falta traducción. La comunidad añade idiomas con un archivo más. Nada de texto
visible fuera de `L`.

## 9. Estructura de archivos

```
LevelMates/
  LevelMates.toc
  Locales/enUS.lua, esES.lua
  Core.lua        -- arranque, SavedVariables, comandos, versión
  Comm.lua        -- transporte (§4): canal, cola, formato, validación
  Roster.lua      -- estado de compañeros (§5), misiones propias
  Match.lua       -- emparejar misiones (§6.2)
  Help.lua        -- pedir ayuda (§6.3), marcadores
  Board.lua       -- tablón (§6.1)
  Settings.lua    -- opciones (§7)
  Questie.lua     -- integración opcional
  Media/          -- icono
tests/            -- runner Lua (node + fengari) con stub del juego; tests por módulo
tools/            -- check-lua, empaquetado (BigWigs packager vía GitHub Actions)
spike/            -- LM_CommTest (desechable)
```

## 10. Pruebas

- Unitarias fuera del juego con fengari: formato/parseo de mensajes (fuzz: nada mal formado rompe),
  cola y presupuesto, caducidad del roster, lógica de emparejar, estado de un aviso de ayuda.
- En el juego: con Diego y Mario, en mundo abierto y dentro de una mazmorra (encuentro: nada sale;
  después: la cola se vacía).
- Comprobaciones de política: un test que falla si aparece `SendChatMessage`, `InviteUnit`,
  `C_PartyInfo.InviteUnit` o `QuestLogPushQuest` fuera de un handler de clic; otro que mide el
  tamaño máximo de mensaje y el ritmo de la cola.

## 11. Publicación

Repo público en GitHub con GitHub Actions y el BigWigs packager: cada tag publica en CurseForge y
Wago. README en inglés y español. CHANGELOG. Sin instalador, sin app.

## 12. Riesgos

| Riesgo | Mitigación |
|---|---|
| GUILD no entrega mensajes en Forever | Canal oculto (§4.1); el roster filtra extraños |
| Forever bloquea mensajes de addon desde temporizadores en el futuro | El latido también se dispara en eventos del jugador (cambio de zona, nivel); si todo falla, el addon avisa y queda en modo solo lectura |
| Varias hermandades grandes saturan | Presupuesto de cola; latido adaptativo (60 s con más de 60 conectados) |
| Posición sin consentimiento | Solo con interruptor; pedir ayuda lo dice en el tooltip |
| Otro addon usa el prefijo `LVLM` | Versión y validación estricta; un mensaje ajeno se ignora |
