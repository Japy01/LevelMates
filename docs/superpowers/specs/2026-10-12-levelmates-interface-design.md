# LevelMates: interfaz, el libro como panel (proyecto 7)

Pedido en chat el 2026-10-12. Tras ver la interfaz de otro addon de hermandad ("parece más completa"), la decisión es **mantener el pergamino** ("Pergamino") y hacer del libro un **panel**: más espacio, recuadros en columnas, cifras grandes y todo dentro de la ventana. Las ideas vienen de su galería pública y de las [notas de funciones](../../research/2026-10-12-guild-features-notes.md); no se copia código, arte ni fuentes de otros addons.

La tecnología es la de siempre: Lua y los marcos del juego, solo con el **arte y las fuentes del propio juego** (pergamino del libro de hechizos, iconos, pantallas de carga; Friz Quadrata, Morpheus, Skurri).

## Por qué

- **Se queda corto:** el libro muestra **una lista por página** en una ventana estrecha (680). Lo que ya sabemos (nivel de objeto, partidas, misiones, quién está dónde, el muro) no se ve de un vistazo.
- **Respuestas y avisos que se pierden:** las respuestas van al chat y los avisos se pierden.
- **Borrados sin red:** borrar no pide confirmación.
- **Subir de nivel:** falta una barra de nivel y un momento especial al subir.

## Fase A: el kit y el panel

### A1. El kit de piezas (`Skin.lua` / `Widgets.lua`)

Piezas reutilizables, todas en pergamino y con tinta:
- **Recuadro:** un marco fino en tinta, con una cabecera en versalitas (título a la izquierda, un dato a la derecha, p. ej. "2 próximas") y una línea de ayuda abajo cuando está vacío ("Nadie busca grupo. Alt+clic en una misión…").
- **Cifra:** un número grande con su etiqueta debajo ("23 · nivel de objeto · 14/17").
- **Píldora:** una etiqueta corta con borde redondeado ("● 3 conectados", "Discord enlazado").
- **Chip:** un botón de pestaña pequeño que se queda marcado (sub-pestañas, filtros, vistas).
- **Casilla de plaza:** el icono de clase con el nombre debajo y el color del rol; vacía, con el rol en gris y borde discontinuo.
- **Botón con "¿Seguro?":** ver A5.

### A2. Una ventana más grande

- El libro pasa a **900 de ancho** (antes 680), con el mismo alto.
- Las columnas de las listas crecen en proporción, sin cambiar qué muestran.
- Las tarjetas de mazmorra pasan de 4 a 5 por fila.

### A3. La barra del título

- A la derecha del título, píldoras con:
  - **"● N conectados"** (con LevelMates);
  - **"Discord enlazado"** si la hermandad lo tiene y yo estoy vinculado;
  - **"Versión antigua: N"** si alguien sigue con la 0.3.
- Al pulsar la de conectados se va a Compañeros.

### A4. Inicio como panel

Inicio deja de ser una lista y pasa a ser un panel:
- **Arriba, cuatro cifras:**
  - el nivel de la hermandad con su barra;
  - los conectados;
  - mi nivel de objeto;
  - el reto de la semana.
- **Izquierda, "Mi personaje":**
  - nombre, nivel y clase;
  - la XP con la parte descansada;
  - el equipo en miniatura (los 17 huecos como cuadritos del color de su calidad);
  - mi rol;
  - mis puntos de la semana.
- **Centro:**
  - "**Ahora**": peticiones de ayuda y anuncios de grupo, con su botón;
  - "**Próximas partidas**": las 2 siguientes, cada una con sus 5 casillas;
  - "**Misiones**": los 3 anuncios más recientes del tablón.
- **Derecha:**
  - "**Quién está dónde**": las zonas con compañeros, con iconos de clase y "+N";
  - "**Hoy en la hermandad**": las últimas entradas del muro.
- El mensaje del día sale como una franja bajo las cifras.
- Cada recuadro, si está vacío, dice qué hacer.
- **Alone**: el texto de invitar a la hermandad, como ahora, en el centro.

### A5. "¿Seguro?"

- **En los botones** que borran: el primer clic pone "¿Seguro?" en rojo; un segundo clic en 5 s lo hace; si no, vuelve.
- **En los menús:** una ventana del juego de Sí/No.
- **Acciones:**
  - cancelar una partida;
  - retirar una misión;
  - borrar una meta;
  - quitar un deseo o una oferta;
  - quitar a alguien de mi partida.

### A6. Barra de mensajes

- Las respuestas a mis clics (lo que hoy va al chat con `ns.Say` después de una acción) salen **al pie del libro** si está abierto:
  - 6 segundos y se desvanecen;
  - verde, naranja o rojo;
  - pulsar la cierra.
- Con el libro cerrado, van al chat como hasta ahora.

## Fase B: partidas en tarjetas, avisos y nivel

### B1. Partidas en tarjetas, y crear partida dentro de Grupos

- **En Grupos**, la vista **Calendario** pasa a llamarse **Partidas**:
  - a la izquierda, las partidas de hoy y mañana como **tarjetas**: hora, mazmorra, líder y nota; las **5 casillas de plaza**; los botones Unirme (por rol libre) / Salir / Invitar a todos / Cancelar;
  - más días, debajo, como ahora.
- **A la derecha, el formulario "Crear partida"**, en la propia pestaña:
  - mazmorra, día (chips Hoy, Mañana y los demás), hora y nota;
  - mi rol (chips);
  - "Anunciar en Discord" con su explicación;
  - el botón **Publicar**.
- El diálogo suelto sigue para cuando se crea desde una tarjeta de mazmorra.

### B2. Bandeja de avisos y tira bajo el minimapa

- Todo aviso queda en una **bandeja** (los últimos 30, como mucho de 2 h).
- **El botón del minimapa** muestra el **número** de no leídos.
- **Una tira bajo el minimapa** enseña el último aviso 10 s:
  - espera si estoy en combate;
  - no sale los primeros 20 s tras entrar.
- **Abrir la bandeja:** pulsar la tira, o Mayús+clic en el botón del minimapa.
- **En la bandeja:** cada aviso con su hora y un botón para ir a lo que toca. Abrirla marca todo como leído.
- **Interruptores:** "Tira bajo el minimapa" (activado); el modo tranquilo la apaga.

### B3. Barra de nivel

- **Apagada por defecto** (`/lm barra` u Opciones). Se puede mover y bloquear.
- **Muestra:**
  - nivel;
  - % de XP con la parte descansada;
  - **XP por hora** (15 min);
  - **tiempo hasta subir**;
  - tiempo en el nivel;
  - enemigos matados en el nivel (del mensaje de XP del chat, con el patrón del propio cliente).

### B4. Cartel al subir de nivel

- Unos 8 s: "¡Nivel 24!", el tiempo que llevó, la XP por hora y el puesto en la carrera.
- Se cierra al pulsar.
- Tiene su interruptor; el modo tranquilo lo apaga.

## Fuera de este proyecto

- **Ventana que se agranda con un tirador:** el libro se dibuja con filas fijas; un tamaño mayor fijo da el espacio necesario sin rehacerlo entero.
- **Fuentes de fuera del juego:** descargarlas no entra en lo acordado; las del juego bastan para el pergamino.
- **Buscador en Opciones:** el panel del juego ya tiene uno.
- **Recolección:** va con las hogueras.

## Pruebas

- **Kit:** cada pieza se crea, se pinta en tinta y se vacía con su texto de ayuda.
- **Ventana:**
  - 900 de ancho;
  - las columnas crecen en proporción y siguen sumando el ancho útil;
  - 5 tarjetas por fila.
- **Píldoras:** conectados, Discord (con `C_Discord` simulado) y versión antigua; la de conectados lleva a Compañeros.
- **Inicio:**
  - las cuatro cifras con sus valores;
  - "Mi personaje" con el equipo en miniatura;
  - las próximas partidas con sus casillas;
  - quién está dónde;
  - el muro;
  - los textos de vacío;
  - el mensaje del día.
- **"¿Seguro?":** el primer clic no hace nada, el segundo en 5 s lo hace, a los 6 s vuelve; los menús piden confirmación.
- **Barra de mensajes:** al pie con el libro abierto; al chat con él cerrado; los colores.
- **Fase B:**
  - tarjetas y formulario (publicar desde el formulario);
  - la bandeja, el número, la tira (combate y primeros 20 s);
  - la barra de nivel (XP/h, tiempo, muertes);
  - el cartel.
