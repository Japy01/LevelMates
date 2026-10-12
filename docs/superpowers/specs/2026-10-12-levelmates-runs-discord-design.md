# LevelMates: partidas, roles, grupos sugeridos y Discord (proyecto 2)

Pedido en chat el 2026-10-12 ("sí, quiero terminarlo, sigue"), dentro de la hoja de ruta de [sincronización v2](2026-10-12-levelmates-sync-v2-design.md). Se apoya en los registros compartidos de ese proyecto. Las ideas salen de las [notas de funciones](../../research/2026-10-12-guild-features-notes.md) y de las [prácticas de sincronización](../../research/2026-10-12-guild-sync-practices.md); no se copia código.

Se publica junto con el proyecto 1 como **0.4.0**.

## Por qué

- **Las quedadas no garantizan un grupo que funcione:** cualquiera se apunta con cualquier rol, aunque ya haya tanque, y el creador no puede ordenar nada.
- **Nadie sabe qué rol hace cada uno** hasta que se apunta a algo.
- **Con gente conectada de niveles parecidos, nadie propone el grupo:** el addon tiene los datos para sugerirlo.
- **Discord:** la hermandad quiere ver las partidas allí sin copiar y pegar.

## 1. Partidas (las quedadas pasan a ser partidas)

La quedada actual (`qd`, `qj`) se convierte en **partida**: mismo sitio en el libro (tarjetas de mazmorra, panel, calendario), mismos datos y además **5 plazas**.

**Plazas:** 1 tanque, 1 sanador y 3 de daño.
- El **líder** (quien la crea) ocupa una plaza desde el principio, con el rol que elige al crearla. Por defecto es su rol preferido (sección 2).
- **Apuntarse** solo deja elegir los roles con plaza libre. Si dos se apuntan a la vez a la última plaza, decide el líder (abajo).
- Una partida llena lo dice ("completa") y ya no ofrece apuntarse.

**El líder manda** (nuevo registro `qm`, de tablón, propiedad del líder, id = el de la partida):
- `qm` es la **lista oficial**: hasta 5 entradas `rol=nombre`, como mucho 200 caracteres. El nombre va entero, apellido incluido; si no cabe, se acorta la nota de la partida, nunca los nombres.
- Cuando el cliente del líder ve un apuntado nuevo (`qj`), lo coloca si su rol tiene plaza y vuelve a publicar `qm`. Si no hay plaza, el apuntado queda **en espera** y se muestra así.
- **El líder puede añadir a mano** a un compañero de la hermandad, para quien se apuntó por voz o por Discord. Se elige de los conectados y su rol tiene que tener plaza. También puede **quitar** a alguien.
- Lo que se muestra es `qm` si existe. Si el líder aún no lo ha publicado (está desconectado), se muestran los apuntados tal cual, marcados como "sin confirmar".
- El líder no puede salirse: cancela la partida.

**"Invitar a todos"** (botón del líder en el panel de la mazmorra):
- invita a los de la lista oficial que estén conectados, sin incluirse a sí mismo;
- usa la grafía de la lista de la hermandad;
- dice en una sola línea a cuántos invitó y quién no estaba conectado.

**Duración:** igual que ahora (hasta 3 horas después de la hora). Se mantiene el aviso 15 minutos antes.

## 2. Rol preferido

- Cada uno elige **Tanque, Sanador o Daño**:
  - en una línea nueva de la pestaña Grupos ("Mi rol: [T] [S] [D]");
  - en Opciones > General.
- Se comparte como estado personal `rol` (el mecanismo común de datos personales), solo cuando cambia y a quien entra.
- **Sin rol elegido, se adivina por la clase**:
  - tanque: Guerrero, Druida, Paladín;
  - sanador: Sacerdote, Druida, Chamán, Paladín;
  - el resto, daño.

  Lo adivinado se marca con "?". Una clase que puede hacer varios roles adivina el primero de su lista: Guerrero tanque, Druida tanque, Paladín tanque, Sacerdote sanador, Chamán sanador.
- La ficha del compañero y la lista de Compañeros muestran el icono del rol.

## 3. "Juntos": grupos sugeridos

Una vista nueva en la pestaña Grupos (botón "Juntos", junto a "Calendario"), y una sección en el panel de cada mazmorra.

**Cómo se arma cada grupo:**
1. Para cada mazmorra se toman los compañeros **conectados** (y yo) cuyo nivel cae en su rango, admitiendo hasta 2 niveles por encima del máximo. Hacen falta al menos 2.
2. Se rellenan las plazas primero con **roles elegidos**, de mayor a menor nivel.
3. Después los huecos de tanque y sanador se cubren con **roles adivinados** por la clase.
4. El resto entra como daño, hasta 3.
5. Las sugerencias se ordenan por plazas cubiertas, luego por número de candidatos y luego la mazmorra más alta. Se muestran como mucho 5.

**Cada sugerencia** muestra la mazmorra y su rango, más las 5 filas (rol, nombre, nivel, "?" si es adivinado). Tiene dos botones:
- **"Crear partida"**: abre el diálogo de partida con la mazmorra puesta y la hora dentro de 15 minutos;
- **"Invitar a todos"**: invita a los sugeridos que estén conectados.

Se calcula **solo en mi cliente** con lo que ya sé (latidos y roles); no se envía nada.

## 4. Discord

Se usa el enlace que el propio WoW Forever hace entre la hermandad y un canal de Discord. **Nada de bots ni webhooks.**

**Cuándo se puede:**
- `C_Discord.IsEnabled()`;
- `C_Discord.IsGuildChannelLinked()`;
- `C_Discord.IsUserOAuthed()`.

Las tres se preguntan protegidas (pcall), y una respuesta desconocida cuenta como "no".

**Requisitos:**
- **El líder de la hermandad** enlaza Discord en Hermandad > Ajustes > Control de hermandad > Discord y marca "chat separado".
- **Cada jugador** vincula su cuenta en Opciones > Social. El juego no deja escribir en ese canal sin vincular.

**Qué se publica** (solo como consecuencia de un clic de esa persona):
- **El líder, al crear la partida**, si marca "Anunciar en Discord". La partida guarda esa marca (`dc = 1`).
- **Quien se apunta, cambia de rol o se sale** de una partida marcada: su propia línea.
- **El líder al añadir o quitar a mano, y al cancelar.**

**Formato de la línea:**
- Una sola línea con la mazmorra, el día, la hora HH:MM, el líder, las plazas libres por rol (o "completa") y la nota.
- Como mucho 236 caracteres; los `|` se quitan. Nunca enlaces de objeto.
- En el idioma del cliente que la escribe.
- Ejemplo: `[LevelMates] Minas de la Muerte · hoy 21:00 · líder Gigasamba · faltan: sanador, 2 daño · "traed pociones"`.

**Si no se puede publicar:**
- **Chat bloqueado** (combate de jefe, instancia restringida, `InChatMessagingLockdown`, o un `ADDON_ACTION_BLOCKED` nuestro en los últimos 30 s): se guarda **solo la última línea de cada partida** y aparece el botón **"Enviar a Discord"** en el panel de la mazmorra. Nunca se reintenta solo: todo lo que va a un chat sale de un clic.
- **Discord no disponible** (la hermandad no lo tiene enlazado o el jugador no está vinculado): la casilla aparece desactivada, con la explicación de qué falta. Al lado se ofrece **"Copiar para Discord"**, que ya existe, con el mismo texto.

**Comprobación al publicar:** si después de enviar salta `ADDON_ACTION_BLOCKED` nombrando a LevelMates, la línea se marca como no enviada y vuelve el botón.

## 5. Mensajes nuevos o cambiados

| Tipo | Clase | Campos | Notas |
|---|---|---|---|
| `qd` (partida) | tablón | `d`, `at`, `n` (nota, 40), `r` (rol del líder), `dc` (0/1) | `r` y `dc` son nuevos |
| `qj` (apuntado) | tablón | `r` | sin cambios |
| `qm` (lista oficial) | tablón, del líder | `m` = "T=Nombre,H=Nombre,D=Nombre,…" (≤200) | nuevo; id = id de la partida; `idOwner`: solo el dueño de la partida |
| `rol` | personal | `r` = T/H/D | nuevo, vía `S.Personal` |

Los anuncios de grupo inmediatos (`lfg`, "busco grupo ahora") se quedan como están.

## 6. Interfaz

- **Diálogo de partida** (el de quedada, renombrado): añade "Mi rol" y la casilla "Anunciar en Discord" con su explicación.
- **Panel de la mazmorra:**
  - cada partida muestra sus 5 plazas: rol, nombre, o "libre" en gris;
  - los apuntados en espera;
  - para el líder: "Invitar a todos", "Añadir…" (menú de conectados), "Quitar" en cada fila y "Enviar a Discord" si hay una línea pendiente;
  - para los demás: "Unirme como T/S/D", solo con los roles libres.
- **Pestaña Grupos:** la línea "Mi rol", el botón "Juntos" y el calendario de siempre.
- **Tarjetas de mazmorra:** la insignia de la partida pasa de "hora · N" a "hora · 3/5".

## 7. Pruebas

Con el simulador de varios jugadores:
- **Plazas:** dos jugadores eligen la última plaza de daño a la vez; el líder coloca a uno y el otro queda en espera, y todos ven lo mismo.
- **Desconexión del líder:** crea la partida y se va; quien entra la ve con la lista oficial.
- **Manual:** el líder añade a uno a mano y lo quita; el rol lleno se rechaza.
- **Rol preferido:** se comparte y llega a quien entra; sin rol, se adivina por la clase.
- **Juntos:**
  - el grupo propuesto con roles elegidos y adivinados;
  - menos de 2 candidatos no da sugerencia;
  - el orden de las sugerencias.
- **Discord** (con `C_Discord` y `SendChatMessage` simulados):
  - una línea por acción, en el formato y por debajo de 236;
  - nada sin la marca;
  - nada sin clic;
  - si está bloqueado, se guarda la última línea y sale el botón;
  - sin vincular, la casilla está desactivada.
- **Invitar a todos:** salta a los desconectados y a mí; resumen en una línea.
- **Migración:** las quedadas de la rama anterior se ven como partidas (líder con rol adivinado, sin `qm`).

## Fuera de este proyecto

- Las misiones de grupo compartidas en "Juntos" van en el proyecto 3 (misiones).
- Un bot de Discord queda fuera para siempre (memoria: es un proyecto aparte del usuario).
- Leer Discord desde el juego no es posible: el texto llega protegido.
