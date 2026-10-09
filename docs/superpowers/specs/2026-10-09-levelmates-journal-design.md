# LevelMates: diario

Segunda parte de la pieza 3 de 4 (metas, diario y XP descansada). La XP descansada ya está hecha; las metas de hermandad y la lista de deseos van después, cada una con su diseño.

## 1. Objetivo

Un registro de tu progreso mientras subes de nivel, para mirar atrás: cuándo subiste cada nivel y cuánto tardaste, qué misiones y mazmorras hiciste, con qué hermanos, qué objetos buenos conseguiste, cómo avanzan tus profesiones y dónde moriste. Éxito: abro la pestaña Diario y veo mi semana de juego con sus hitos.

## 2. Alcance

**Dentro:** siete tipos de entrada (§4); pestaña "Diario" en el tablón con filtro por tipo y la búsqueda existente; borrado con confirmación; límite de 1000 entradas por personaje; simulación `/lm sim diario`.

**Fuera, a propósito:** compartir con la hermandad (es solo tuyo); lista de deseos (función aparte, después); estadísticas o gráficos; exportar.

## 3. Privacidad

Todo se guarda en tu ordenador, en los datos del addon de cada personaje. Nada viaja por la red: el diario no envía ningún mensaje.

## 4. Entradas

Cada entrada guarda: tipo, fecha y hora (`time()`), zona (`GetRealZoneText()`), y los datos de su tipo.

| Tipo | Cuándo | Datos |
|---|---|---|
| Nivel | `PLAYER_LEVEL_UP` | nivel nuevo; tiempo desde la entrada de nivel anterior (si existe) |
| Misión | `QUEST_TURNED_IN` | id y nombre de la misión (`C_QuestLog.GetTitleForQuestID`) |
| Mazmorra | al entrar en una instancia de tipo grupo (`IsInInstance()` = party) | nombre que da el juego (`GetInstanceInfo()`), hermanos del grupo que estén en el roster |
| Grupo | `GROUP_ROSTER_UPDATE`, por cada hermano del roster que pasa a estar en mi grupo | su nombre; una vez por persona y sesión |
| Objeto | `CHAT_MSG_LOOT` cuyo `guid` es el mío (`UnitGUID("player")`) y cuyo enlace de objeto es de calidad poco común (verde) o mejor | el enlace del objeto |
| Profesión | `SKILL_LINES_CHANGED`, comparando con lo último visto (`C_SkillInfo`) | profesión aprendida, o nuevo múltiplo de 25 alcanzado |
| Muerte | `PLAYER_DEAD` | nivel en ese momento |

Reglas:
- La calidad del objeto sale de la información del objeto; si el cliente aún no la tiene, del color del enlace.
- La mazmorra se apunta una vez por entrada en la instancia, no por cada carga de pantalla dentro de ella.
- Las profesiones se comparan con una foto guardada; la primera vez que se ve el personaje solo se toma la foto, sin entradas (para no inundar el diario con todo lo que ya tenías).
- Dentro de una instancia se apunta igual: el diario es local y no envía nada.

## 5. Interfaz

- Tercera pestaña **"Diario"** en el tablón, junto a Hermanos y Mazmorras.
- Lista de la más reciente a la más antigua, una línea por entrada: hora o fecha, icono o etiqueta del tipo, texto y zona.
- Filtro por tipo con el menú del juego (Todo, Niveles, Misiones, Mazmorras, Grupos, Objetos, Profesiones, Muertes).
- La caja de búsqueda filtra por texto de la entrada.
- Al pasar el ratón por una entrada de objeto se ve su ficha (`GameTooltip:SetHyperlink`).
- Botón **"Borrar diario"** con confirmación (`StaticPopup`).
- Si hay más entradas de las que caben, se pasa de página con dos botones (anterior/siguiente); sin barra de desplazamiento.

## 6. Almacenamiento

- `ns.char.journal` = lista de entradas, la más antigua primero.
- Máximo 1000 por personaje: al añadir la 1001, se borra la más antigua.
- La foto de profesiones en `ns.char.skills`.

## 7. Pruebas

- Una prueba por tipo de entrada, con sus datos.
- Nivel: tiempo desde el nivel anterior.
- Objeto: solo los míos (guid), solo verde o mejor, calidad por información o por color.
- Mazmorra: una vez por entrada en la instancia; hermanos del grupo.
- Grupo: una vez por persona y sesión.
- Profesión: primera vez sin entradas; aprendida; cada 25.
- Límite de 1000.
- Pestaña: orden, filtro, búsqueda, páginas, ficha del objeto, borrado con confirmación.
- Nada enviado por la red.
- Simulación `/lm sim diario`.

## 8. Riesgos

- El aviso de botín y la información de profesiones de Forever se comprueban en el juego; si el de botín no fuera fiable, se quita solo ese tipo.
- El diseño de la tercera pestaña y la fila de botones de abajo hay que verlo en el juego.
