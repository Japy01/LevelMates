# LevelMates: buscar grupo de mazmorra

Pieza 1 de 4 para la primera versión pública (las otras: compañero de leveo; metas, diario y XP descansada; Discord). Se apoya en lo ya construido: mensajes por hermandad, roster, tablón y el cumplimiento de la política de Blizzard descrito en la spec de v1.

## 1. Objetivo

Que un hermano diga "busco grupo para esta mazmorra, hago este rol" y los demás lo vean al instante en el tablón, con un clic para invitarle o susurrarle. Éxito: dos hermanos con el addon se encuentran para una mazmorra sin escribir una línea en el chat de hermandad.

## 2. Alcance

**Dentro:** anunciar y retirar un anuncio; lista en una pestaña nueva del tablón; aviso en el chat cuando un anuncio encaja con mi nivel; opción para apagar esos avisos; simulación local con `/lm sim`.

**Fuera, a propósito:** avisar de qué rol falta en mi grupo; emparejar automáticamente; unirse a la cola oficial del juego; historial de anuncios; filtros por rol.

## 3. Política (heredada de v1, sin excepciones nuevas)

- Publicar y retirar un anuncio salen **solo de un clic** del jugador (botón del tablón o comando). Nada se publica solo.
- Solo mensajes de addon a la hermandad, sin combate. Requiere "Aparecer en el tablón" activo, igual que pedir ayuda.
- Dentro de una instancia no se envía nada (solo `help` y `helpok`, como hasta ahora). Un anuncio que me pille entrando a una mazmorra caduca por su propio reloj en los demás.
- Invitar y susurrar siguen saliendo solo del clic derecho sobre una fila.

## 4. Mensajes

Dos tipos nuevos, `lfg` y `lfgx`, con el mismo formato `v1` y las mismas reglas de validación campo a campo. Un addon sin esta función los descarta en silencio y los cuenta como mensajes ignorados.

| kind | Cuándo | Campos |
|---|---|---|
| `lfg` | el jugador publica; y reenvío para quien acaba de conectarse (respuesta a `ping`, escalonada 0-5 s y agrupada igual que el latido) | `d` id de mazmorra (entero 1-99), `r` roles (subconjunto de `T`, `H`, `D`, sin repetir, máx. 3 letras), `n` nota (texto ≤ 40, opcional), `id` identificador (palabra ≤ 8), `m` minutos que le quedan (entero 1-20) |
| `lfgx` | el jugador lo retira, o el grupo llega a 5 | `id` |

Requeridos en `lfg`: `d`, `r`, `id`, `m`. El nivel y la clase del que anuncia **no viajan** aquí: se leen del roster (su latido). Si el roster no conoce a ese jugador, el anuncio se ignora.

Un jugador tiene como mucho un anuncio. Uno nuevo suyo con otro `id` sustituye al anterior. Límite de ritmo: un anuncio nuevo por jugador cada 30 s (el emisor lo respeta; el receptor ignora los que lleguen antes). Límite de la lista en un receptor: 50 anuncios.

## 5. Ciclo de vida de un anuncio

- Al recibirlo, el receptor guarda `caduca = ahora + m × 60`. El reenvío a un recién llegado lleva los minutos que **quedan**, así que un anuncio nunca se alarga.
- Caduca a los 20 minutos desde que se publicó, salvo que se retire antes. No se renueva solo: para ampliarlo hay que volver a publicar.
- El emisor lo retira (`lfgx`) de dos formas: con el botón "Cancelar anuncio", o automáticamente cuando su grupo llega a 5 personas (`GetNumGroupMembers() ≥ 5`). Al recibir `lfgx` solo cuenta si viene del mismo jugador que publicó ese `id`.
- Un receptor purga los caducados cada 60 s y al abrir el tablón.

## 6. Interfaz

- El tablón tiene dos pestañas: **Hermanos** (la actual) y **Mazmorras**. La cabecera, el buscador y los botones de abajo se mantienen.
- La pestaña Mazmorras es una lista con: mazmorra y su rango de nivel, roles, jugador (icono de clase, nombre, nivel) y nota. Orden: la más reciente arriba. Clic derecho: Invitar, Susurrar (el mismo menú que en Hermanos).
- Botón **Buscar grupo** abre un cuadro con: mazmorra (se elige con el menú contextual del juego), tres casillas de rol y una caja de texto para la nota. Si ya tengo un anuncio, el botón pasa a **Cancelar anuncio**.
- Aviso en el chat: "Mario busca grupo para Sima Ígnea (tanque, daño)." Solo si mi nivel está dentro del rango de esa mazmorra y la opción está activa, y una sola vez por anuncio. Sin sonido.
- Ajuste nuevo: "Avisos de grupos de mazmorra" (activado por defecto).

## 7. Lista de mazmorras

Una tabla dentro del addon: id, clave de nombre (textos en inglés y español), nivel mínimo y máximo. No se lee la lista del juego en ejecución porque no hemos podido verificar esa API en Forever.

**Fuente de los datos.** Los rangos de las seis mazmorras que se ven en el diario del usuario (captura) mandan sobre cualquier web: Salón de los Feudales 13-20, Sima Ígnea 13-18, Ruinas de Lordaeron 15-22, Minas de la Muerte 17-26, Cuevas de los Lamentos 15-24, Castillo de Colmillo Oscuro 20-30. El resto sale de [warcrafttavern.com](https://www.warcrafttavern.com/forever/guides/dungeons/), que coincide con el diario en cinco de esas seis (difiere solo en Sima Ígnea, donde la web dice 13-20 y el diario 13-18). Otras webs dan rangos distintos para varias mazmorras, y Forever está en beta, así que **todo rango que no esté en la captura es provisional hasta compararlo con el diario en el juego**.

Lista provisional (35 entradas; las alas de Scarlet Monastery, Stratholme y Dire Maul cuentan por separado). Nombres en inglés tal como los da la fuente; los nombres en español se toman del diario del juego y hasta entonces el addon muestra el inglés:

| Mazmorra | Niveles |
|---|---|
| Hall of Thanes (diario: Salón de los Feudales) | 13-20 |
| Ragefire Chasm (diario: Sima Ígnea) | 13-18 (la web dice 13-20) |
| Ruins of Lordaeron (diario: Ruinas de Lordaeron) | 15-22 |
| Wailing Caverns (diario: Cuevas de los Lamentos) | 15-24 |
| The Deadmines (diario: Minas de la Muerte) | 17-26 |
| Shadowfang Keep (diario: Castillo de Colmillo Oscuro) | 20-30 |
| Blackfathom Deeps, The Stockade | 24-32 |
| Excavation Site: Wetlands | 26-33 |
| City of Dalaran | 28-33 |
| Gnomeregan, Razorfen Kraul | 29-38 |
| Scarlet Monastery: Graveyard / Library / Armory / Cathedral | 30-38 / 33-41 / 36-44 / 38-46 |
| The Drowned City | 35-40 |
| Razorfen Downs | 37-46 |
| Krol'dok Stronghold | 40-45 |
| Zul'Farrak | 40-47 |
| Uldaman | 41-51 |
| Maraudon | 45-51 |
| Alcaz Island Prison | 48-53 |
| Temple of Atal'Hakkar | 50-55 |
| Blackrock Depths | 52-60 |
| Blackmaw Hold | 55-60 |
| Lower Blackrock Spire / Upper Blackrock Spire | 57-60 / 60 |
| Shaper's Terrace | 58-60 |
| Dire Maul East / West / North | 58-60 / 60 / 60 |
| Stratholme Living / Undead, Scholomance | 58-60 |

El selector del cuadro "Buscar grupo" agrupa por tramo de nivel para no mostrar 35 líneas seguidas.

## 8. Pruebas

- Formato: ida y vuelta de `lfg` y `lfgx`, rechazo de roles repetidos o fuera de `T/H/D`, nota demasiado larga, `m` fuera de rango, id desconocido.
- Ciclo de vida: caduca a los 20 min; el reenvío a un recién llegado conserva el tiempo restante; solo el autor puede retirar su anuncio; uno nuevo sustituye al anterior; se cierra al llegar a 5 en el grupo.
- Política: nada se envía sin clic, nada dentro de instancias, nada con "Aparecer en el tablón" apagado.
- Interfaz: la lista respeta orden y límite; el aviso sale una vez y solo si encaja; el botón cambia a "Cancelar anuncio".
- Simulación: `/lm sim` crea anuncios locales; `/lm sim off` los quita.
- En el juego, con otra persona: verse, invitar desde la fila, caducidad real.

## 9. Riesgos y dudas

- La lista de mazmorras de Forever está incompleta en este documento; hay que completarla en el juego.
- No sabemos si en Forever `GetNumGroupMembers()` cuenta igual que en la versión principal; el cierre al llegar a 5 se comprobará en el juego.
- Si dos hermanos publican a la vez, ambos ven los dos anuncios; es lo esperado.
