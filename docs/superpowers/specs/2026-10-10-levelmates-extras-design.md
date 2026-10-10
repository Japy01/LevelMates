# LevelMates: tanda de mejoras (títulos, avisos, versión, felicitar, ritmo, oficios, «Me apunto»)

El usuario pidió ideas para mejorar el addon y aprobó con "hazlo" las recomendadas: títulos por pestaña, avisos en pantalla con aviso de versión, felicitar subidas de nivel, tu ritmo, directorio de profesiones y «Me apunto» en las tarjetas de mazmorra. Todo dentro del juego, con mensajes nuevos de tipo propio y acciones solo desde clics.

## 1. Títulos por pestaña

El título grande y la línea de ayuda de arriba cambian con la pestaña:

| Pestaña | Título | Ayuda |
|---|---|---|
| Hermanos | Hermanos conectados | Clic derecho: invitar, susurrar o punto de ruta. |
| Mazmorras | Mazmorras | Clic en una tarjeta: apuntarte, susurrar, invitar o buscar grupo ahí. |
| Diario | Mi diario | Tu ritmo (ver 5) o, sin datos, "Tu viaje: niveles, misiones, mazmorras, botín…" |
| Metas | Metas | Metas de la hermandad y metas personales. |
| Deseos | Deseos | Mayús+clic en un objeto para añadirlo; clic derecho en el tuyo para quitarlo. |
| Oficios | Oficios | Quién tiene cada profesión y a qué nivel. Clic derecho: susurrar. |

El texto de ayuda del buscador también cambia (buscar nombre / mazmorra o jugador / texto / objeto o nombre / profesión o nombre).

## 2. Avisos en pantalla

`ns.Notice(fmt, …)`: la línea del chat de siempre y, si la opción "Avisos en pantalla" está encendida (por defecto sí), el mismo texto en el centro de la pantalla (`UIErrorsFrame`, en dorado). Se usa para lo importante: anuncio de mazmorra de mi nivel, petición de ayuda, compañero de subida encontrado, meta creada o cumplida, meta personal cumplida, objeto de mi lista conseguido, objeto que quiere un hermano, subida de nivel de un hermano, alguien se apunta a mi grupo, grupo completo y versión nueva. Los mensajes de error y confirmación siguen solo en el chat.

## 3. Aviso de versión

Cada latido ya lleva la versión (`v`). Si un hermano tiene una versión mayor que la mía (comparando números `x.y.z`), aviso una vez por sesión: "Hay una versión nueva de LevelMates (x.y.z)". Sin aviso si mi versión no es numérica (copia de desarrollo).

## 4. Felicitar

Cuando el latido de un hermano conectado trae un nivel mayor que el que tenía (y ya lo conocía), aviso "Mario ha llegado a nivel 30" con un enlace **[Felicitar]** en el chat. Al pulsarlo, le susurro "¡Felicidades por el nivel 30!". Opción "Avisos de subidas de nivel" (encendida por defecto). El enlace es de tipo `addon:LevelMates:cheer:<nombre>:<nivel>` (el juego lo entrega por `EventRegistry` "SetItemRef").

## 5. Tu ritmo

Del diario: media de los últimos 5 niveles con tiempo registrado, el nivel más rápido y, por debajo de 60, la proyección "nivel 60 en ~N h" (media × niveles que faltan, aproximada). Hace falta al menos 2 niveles con tiempo. Se ve como línea de ayuda de la pestaña Diario.

## 6. Oficios

- Mensaje nuevo **`pf`**: `p` = "id:rango,…" (hasta 6 profesiones de las 12 conocidas, rango 1-450); sin `p` = no comparto. Mis profesiones salen del registro de habilidades que ya hace el diario.
- Se envía al cambiar (subida de habilidad, nueva profesión), al anunciarme y a quien se conecta; si se rechaza, queda pendiente en los datos del personaje. Solo el más reciente espera en la cola.
- Opción "Compartir mis profesiones" (encendida por defecto); al apagarla, retiro las mías.
- Lo de los demás se guarda por cuenta y hermandad, se olvida a los 30 días sin noticias y no se muestra de quien ya no está en la hermandad.
- Sexta pestaña **"Oficios"**: quién, profesión, rango y si está conectado (o cuándo se le vio). Ordenado por profesión y rango. El buscador filtra por nombre o profesión. Clic derecho: susurrar (e invitar si está conectado). Páginas si hay más de 20. "Copiar para Discord" agrupa por profesión.

## 7. «Me apunto»

- Mensajes nuevos **`lfj`** (`id` del anuncio, `r` = mi rol T/H/D) y **`lfjx`** (`id`: me borro).
- En el menú de una tarjeta, por cada anuncio de otro: "Me apunto con X como tanque / sanador / daño" o, si ya estoy, "Me borro del grupo de X".
- Quien publicó el anuncio recibe el aviso "Ana se apunta a tu grupo de Minas como sanador"; con 5 (él y 4 apuntados) recibe "¡Tu grupo de Minas está completo!" una vez. En su menú aparece "Invitar a Ana (sanador)" por cada apuntado.
- Todos ven los apuntados en el tooltip de la tarjeta. Solo se aceptan apuntes de hermanos del roster y a anuncios que existen; al desaparecer el anuncio, desaparecen sus apuntes. Mis apuntes se reenvían a quien se conecta.

## 8. Simulación y pruebas

`/lm sim oficios` crea profesiones falsas de Mario y Ana (solo en local). Pruebas de cada parte: textos por pestaña, `ns.Notice` y su opción, comparación de versiones, aviso y enlace de felicitar, cálculo del ritmo, formato y difusión de `pf`, pestaña Oficios, `lfj`/`lfjx` con avisos y grupo completo.

## 9. Riesgos

- El enlace `addon:` en el chat y `EventRegistry` se comprueban en el juego.
- Susurrar desde el enlace usa `SendChatMessage`, que solo funciona desde un clic y fuera de restricciones de chat.
