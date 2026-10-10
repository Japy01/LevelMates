# LevelMates: muro, mercadillo, quedadas, raros, progreso de misiones, mapa y botón de pánico

El usuario pidió "todas" las ideas propuestas. Se implementan en dos planes: **A (social)**: muro, mercadillo, quedadas; **B (subir de nivel)**: raros, progreso de misiones del grupo, mapa de la hermandad, botón de pánico. Todo dentro del juego, mensajes nuevos de tipo propio, solo hermanos del roster, nada dentro de instancias ni con "Aparecer en el tablón" apagado.

## A1. Muro de la hermandad (séptima pestaña "Muro")

- Lo que pasa en la hermandad, lo más nuevo arriba: "Mario subió a nivel 30", "Ana completó Minas de la Muerte con Luis", "Pepe consiguió [Espada]", "Meta cumplida: todos a nivel 20", "Ana cumplió su meta personal: nivel 25".
- Mensaje **`fe`**: `k` (`lvl`, `dun`, `itm`, `pgl`), `a` (nivel, id de objeto o nivel de la meta personal; 0 si no aplica), `b` (texto: nombre de la mazmorra y acompañantes, hasta 60), `t` (minutos desde 1970). Lo envía quien vive el suceso: al subir de nivel, al entrar en una mazmorra con hermanos (lo que ya registra el diario), al conseguir un objeto raro o mejor (azul+), al cumplir su meta personal.
- Las metas de hermandad cumplidas y las subidas de nivel vistas por latido también entran en el muro local sin mensaje extra.
- A quien se conecta le reenvío mis sucesos de las últimas 24 h (como mucho 5), así ve lo que se perdió.
- Se guarda por cuenta y hermandad: 200 entradas, 7 días; sin repetidos (quién + tipo + dato + minuto; una subida al mismo nivel solo una vez).
- Opciones: "Compartir en el muro" (sí) y "Botín en el muro" (sí, azul o mejor).
- La pestaña: cuándo ("hace 2 h"), quién, qué. Ratón sobre un objeto: su ficha. "Copiar para Discord" incluido. Buscador por nombre o texto.

## A2. Mercadillo de regalos (en la pestaña Deseos)

- Botón "Regalar" (abajo a la derecha): el mismo cuadro de Mayús+clic que "Añadir deseo", hasta 10 objetos.
- Mensaje **`gv`** con mi lista de regalos (`ids`, como `wl`); se guarda igual que los deseos (30 días, solo hermanos).
- La pestaña Deseos muestra deseos y regalos, con una columna "Quiere / Regala".
- **Cruce automático**: si alguien regala algo de mi lista de deseos, aviso "Ana regala [X], que está en tu lista. Clic derecho en su fila para reservarlo." Si alguien desea algo que yo regalo, aviso "Mario quiere [X], que tú regalas."
- **Reservar**: clic derecho en un regalo de otro → "Reservar". Mensaje **`gr`** (`i` objeto, `to` quien regala). Quien regala recibe "Mario reserva tu [X]" y la fila muestra "reservado por Mario". El intercambio lo hacen ellos en el juego; quien regala lo quita de su lista con clic derecho → "Quitar".
- El tooltip de objetos añade "Lo regala: Ana" junto a "Lo quiere".

## A3. Quedadas (en las tarjetas de Mazmorras)

- Menú de una tarjeta → "Quedar aquí…": cuadro con día (hoy, mañana o los 5 siguientes), hora (de 0 a 23), minutos (00, 15, 30, 45) y nota.
- Mensajes **`qd`** (`id`, `d` mazmorra, `at` minutos desde 1970, `n` nota), **`qdx`** (`id`, la quita quien la creó) y, para apuntarse, **`qj`** (`id`, `r` rol) / **`qjx`** (`id`).
- La tarjeta muestra la próxima quedada ("sáb 21:00 · 3"); el tooltip lista quedadas y apuntados; el menú: "Me apunto a la quedada del sáb 21:00 como tanque/sanador/daño", "Me borro", y para quien la creó "Cancelar la quedada".
- Quien la creó la reenvía a quien se conecta (y quien está apuntado, su apunte); se guardan hasta 3 h después de la hora.
- **Recordatorio** 15 minutos antes, a quien la creó y a los apuntados (aviso en pantalla).
- Hasta 10 quedadas a la vez en la hermandad; como mucho 2 creadas por persona.

## B1. Avistamiento de raros

- Al seleccionar o pasar el ratón por un enemigo raro o élite raro (vivo), envío **`rr`** (`n` nombre, `z` mapa, `x`, `y` mi posición). Una vez cada 15 minutos por raro.
- Los hermanos que están en ese mismo mapa reciben "Mario ha visto a [Nombre] en Los Baldíos" con un enlace **[Ruta]** que pone el punto de ruta. Opción "Avisos de raros" (sí).
- Si el juego devuelve valores protegidos (en combate en Midnight), no se envía nada.

## B2. Progreso de misiones del grupo

- En grupo con hermanos: para cada misión que compartimos (la lista de misiones de cada uno ya viaja), envío **`qo`** (`i` id de misión, `o` "6/10,1/1") cuando cambia, con 2 s de calma entre envíos.
- En la pestaña Hermanos, el tooltip de un compañero de grupo muestra "Misiones en común" con su progreso. Cuando un compañero termina una misión que compartimos, aviso "Mario ya tiene completa [misión]".

## B3. Mapa de la hermandad

- En el mapa del mundo, un punto con el icono de clase por cada hermano que comparte su posición (opción que ya existe) y está en el mapa que se ve; ratón encima: nombre, nivel y zona. Opción "Hermanos en el mapa" (sí).
- En la pestaña Hermanos, bajo el título, la zona con más hermanos: "3 hermanos en Vega de Tuercespina".

## B4. Botón de pánico

- Un atajo de teclado asignable ("LevelMates: pedir ayuda ya") que envía al momento una petición de ayuda con mi posición y el texto "¡Ayuda! Me están matando". Como mucho una vez cada 30 s.

## Pruebas

Formato y límites de cada mensaje nuevo; quién puede enviar y qué se ignora; guardado y olvido; avisos (una vez); reenvío a quien se conecta; interfaz de cada pestaña y menú; simulación (`/lm sim muro`, `/lm sim mercadillo`, `/lm sim quedada`, `/lm sim raro`).

## Riesgos

- El lienzo del mapa del mundo y sus coordenadas se comprueban en el juego.
- La hora de las quedadas usa el reloj de cada PC (`time()`); con relojes muy desajustados la hora puede bailar unos minutos.
- `UnitClassification` y los nombres de enemigos pueden ser valores protegidos en combate: se comprueban con `issecretvalue`.
