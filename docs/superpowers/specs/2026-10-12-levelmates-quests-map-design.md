# LevelMates: tablón de misiones y mapa (proyecto 3)

Pedido en chat el 2026-10-12 ("sigue"), dentro de la hoja de ruta de [sincronización v2](2026-10-12-levelmates-sync-v2-design.md). Se apoya en los registros compartidos y en el diseño de [partidas](2026-10-12-levelmates-runs-discord-design.md). Las ideas vienen de las [notas de funciones](../../research/2026-10-12-guild-features-notes.md); no se copia código ni datos de otros addons.

Sale en la **0.4.0**, junto con los proyectos 1 y 2.

## Por qué

- **Misiones:** no hay forma de decir "busco gente para esta misión". Los anuncios de grupo son solo de mazmorras, y emparejar misiones solo avisa a quien ya la tiene.
- **"Juntos"** propone grupos de mazmorra, pero no dice qué misiones de grupo tenéis en común.
- **Mapa:**
  - los marcadores salen solo en el mapa exacto de cada zona, no en el del continente;
  - cambian de tamaño con el zoom;
  - se amontonan cuando hay mucha gente en el mismo sitio;
  - no hacen nada al pulsarlos;
  - las posiciones pueden tener hasta 80 s de retraso.

## 1. Tablón de misiones

**Publicar:**
- **Alt+clic en una misión del registro de misiones** publica "busco grupo para esta misión". Otro Alt+clic en la misma la retira.
- El gancho es `hooksecurefunc` sobre los botones del registro que tenga este cliente: `QuestMapLogTitleButton_OnClick` y/o `QuestLogTitleButton_OnClick`, con `IsAltKeyDown()`. Si ninguno existe, solo queda la otra vía.
- **Otra vía, siempre disponible:** en la pestaña Grupos, el botón "Buscar para una misión" abre un menú con las misiones de mi registro.

**Qué se publica** (registro de tablón `qh`, id = `questId .. "." .. NameKey(yo)`):
- `q` = id de la misión;
- `t` = título (40 caracteres);
- `l` = nivel recomendado;
- `z` = la cabecera del registro (la zona, en clásico, 30 caracteres);
- `o` = mis objetivos "hecho/necesario,…" (40 caracteres);
- `g` = 1 si es de grupo, élite o mazmorra.

**Duración y retirada:**
- Dura **2 horas**.
- Se retira solo al entregar la misión (`QUEST_TURNED_IN`) o al abandonarla (`QUEST_REMOVED`).
- Volver a publicar la misma misión la renueva.

**"Yo también"** (registro de tablón `qhj`, id = `idDelAnuncio .. "." .. NameKey(yo)`, campo vacío): me apunto a un anuncio. Mientras exista el anuncio, aparezco en su lista.

**Vista "Misiones" en la pestaña Grupos** (botón junto a "Juntos" y "Calendario"):
- **Filas:** misión, nivel (en verde si está a 5 niveles o menos del mío), zona, quién busca, "+N" de los que también buscan y hace cuánto.
- **Filtros:** Todas / Mi zona / Mi nivel ±5 / De grupo.
- **Al pulsar una fila, un menú con:**
  - "Yo también" o "Quitarme";
  - Susurrar;
  - Invitar;
  - "Invitar a todos" (si es mía);
  - "Retirar" (si es mía).
- **Descripción emergente:**
  - los objetivos del que busca;
  - mis objetivos de la misma misión, leídos de mi registro (si la tengo);
  - la lista de los que también buscan.

**Avisos** (el interruptor de avisos de grupos ya existente):
- un anuncio nuevo de una misión que **tengo**: "Mario busca gente para «La venganza de Gann» (tú también la tienes)";
- un anuncio de una misión de **mi nivel ±5**, si es de grupo.

Los anuncios que llegan por la puesta al día al entrar no avisan.

## 2. Misiones de grupo en común, en "Juntos"

Debajo de los grupos sugeridos, una sección **"Misiones de grupo en común"**:
- las misiones de **mi registro** que son de grupo, élite o mazmorra (`C_QuestLog.GetQuestTagInfo`, solo de las mías), sin terminar;
- y que al menos un compañero **conectado** también tiene, según sus listas de misiones (solo de quien comparte misiones, que es opcional y viene apagado).

Cada fila muestra la misión y quién más la tiene. Al pulsarla:
- "Buscar grupo" la publica en el tablón;
- "Invitar a todos" invita a los que la tienen.

No se envía nada nuevo: se usa lo que ya llega.

## 3. Mapa

**Tamaño fijo:** los marcadores miden lo mismo en pantalla sea cual sea el zoom (escala = escala de la interfaz ÷ escala del lienzo). Tamaño por defecto 18; en Opciones, de 12 a 32.

**Continente:**
- en el mapa de un continente salen todos los compañeros de sus zonas;
- las posiciones de zona se pasan a coordenadas del mundo y de ahí al continente (`C_Map.GetWorldPosFromMapPos`, `C_Map.GetMapPosFromWorldPos`);
- un punto que cae fuera del mapa visto no se pinta.

**Agrupados:**
- 4 o más marcadores a menos de un marcador de distancia se pintan como **un disco dorado con el número**;
- su descripción emergente lista los nombres;
- el agrupado es voraz y estable: de arriba a la izquierda a abajo a la derecha, por nombre;
- mi propia posición cuenta para agrupar, pero nunca se pinta (el juego ya pinta mi flecha).

**Nombres:**
- opcional (en Opciones, apagado por defecto): el nombre de pila sobre cada marcador;
- la descripción emergente: nombre completo, nivel, clase, rol y hace cuánto se actualizó la posición.

**Pulsar un marcador** pone la ruta hacia esa persona (la ruta del proyecto 0.3.2), y en un disco agrupado, hacia el primero. Es un clic, como manda la política.

**Posiciones frescas:**
- al abrir el mapa del mundo, el cliente pide posiciones (`mpq`, como mucho una vez cada 30 s);
- los compañeros que comparten posición contestan con su latido, tras un tiempo al azar de 0,5 a 6,5 s;
- un marcador sin actualizar en **5 minutos** desaparece.

**Rendimiento:**
- los marcadores se reutilizan;
- el mapa se repinta solo mientras está abierto, como mucho cada 0,5 s (el mecanismo de redibujado agrupado);
- nada se calcula con el mapa cerrado.

## 4. Mensajes nuevos

| Tipo | Clase | Campos | Notas |
|---|---|---|---|
| `qh` | tablón | `q`, `t`, `l`, `z`, `o`, `g` | 2 h; id = `questId.NameKey` |
| `qhj` | tablón | (ninguno) | id = `idAnuncio.NameKey`; `idOwner`: solo el propio |
| `mpq` | mensaje suelto, normal | (ninguno) | pedir posiciones; contestan solo quienes comparten posición |

## 5. Fuera de este proyecto

- **Hogueras y barra de campamento:** necesitan los identificadores de los objetos del sistema de campamento de Forever. No los tenemos de una fuente propia y no se copian de otro addon. Quedan para cuando los saquemos del propio juego.
- **Recolección** (marcar hierbas y minerales): proyecto 7.
- **Compartir misiones de grupo sin tener activado "compartir misiones":** sería un cambio de privacidad, así que no se hace.

## 6. Pruebas

Con el simulador de varios jugadores y el de un solo cliente:
- **Alt+clic:**
  - publica;
  - otro Alt+clic retira;
  - entregar la misión la retira;
  - un anuncio de alguien que se fue sigue visible para quien entra después, durante 2 h.
- **"Yo también":**
  - la lista;
  - quitarme;
  - solo el propio puede apuntarse con su id.
- **Avisos:**
  - una misión que tengo;
  - una de mi nivel;
  - nada por la puesta al día.
- **Juntos:**
  - una misión de grupo que tenemos dos aparece;
  - una de un solo jugador no.
- **Mapa** (con un lienzo simulado):
  - tamaño fijo con distinta escala;
  - 4 juntos se agrupan y 3 no;
  - continente: la conversión de coordenadas y lo que cae fuera;
  - yo no me pinto;
  - 5 minutos y desaparece;
  - pulsar pone la ruta;
  - pedir al abrir, como mucho una vez cada 30 s;
  - solo contesta quien comparte posición.
