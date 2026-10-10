# LevelMates: anuncios del chat, ficha de hermano y pestaña Clase (builds y macros)

Aprobado en chat el 2026-10-10 ("ok"), tras investigar addons parecidos (LFG Bulletin Board, FOCUS, GuildForge, Talent Planner, ClassMacros, MacroShare) y comprobar en el juego (`/lm sim build`) que Forever genera el código de build tras abrir la ventana de talentos y que un enlace de build abre la ventana "Talentos vinculados".

## 1. Anuncios del chat en las tarjetas

- Se leen los canales públicos (no el oculto del addon). Un mensaje cuenta si nombra una mazmorra (nombres y abreviaturas en español e inglés, sin acentos ni mayúsculas) y tiene una palabra de grupo (lfm, lfg, need, busco, buscamos, falta, tank, heal, dps, grupo…).
- Uno por jugador (el último), 10 minutos. Mis mensajes no cuentan. Nada se lee si el juego protege el texto (secret values).
- Tarjeta: "2 buscan · 3 en el chat". Tooltip: "Chat · Pepe: «LFM DM need heal» (hace 2 min)". Menú: "Susurrar a Pepe (chat)".
- Opción "Leer anuncios del chat" (sí).

## 2. Ficha de hermano

Clic izquierdo en un hermano del tablón: ventana con clase, nivel, zona y si está conectado (o cuándo se le vio), build (con "Ver build"), profesiones, deseos y regalos, meta personal, lo último suyo en el muro y las quedadas a las que va. Botones Susurrar, Invitar y Punto de ruta (si comparte posición).

## 3. Pestaña Clase

- **Builds de la hermandad** (`tb`: clase, especialización, nivel, puntos por rama, código si lo hay): el mío se comparte al cambiar talentos o subir de nivel y a quien se conecta; los de mi clase se listan con sus puntos por rama ("Reprensión 9 / Sagrado 0 / Protección 0") y nivel; "Ver build" abre la ventana del juego con un enlace de build (solo si hay código: el juego lo da después de abrir los talentos una vez). Opción "Compartir mi build" (sí).
- **Biblioteca de macros por clase**: escritas para LevelMates, con los nombres de hechizo del idioma del jugador (si un hechizo no existe en este cliente, esa macro no sale). "Crear" la añade a las macros del personaje (no en combate; avisa si ya existe o no hay hueco).
- **Macros de la hermandad** (`mc` / `mcx`): comparto hasta 5 macros mías (botón "Compartir macro"); los de mi clase las ven con su texto en el tooltip y las añaden con un clic.

## 4. Ventana

Con nueve pestañas la ventana pasa de 600 a 680 de ancho; las columnas de texto ganan ese espacio.

## Pruebas

Reconocimiento de mensajes (alias, palabra de grupo, acentos, sin falsos positivos), caducidad, tarjetas; contenido de la ficha; lectura de ramas y puntos, `tb`, lista por clase y enlace; biblioteca (nombres localizados, creación, sin hueco, en combate), `mc`/`mcx`, límites; ancho de la ventana.
