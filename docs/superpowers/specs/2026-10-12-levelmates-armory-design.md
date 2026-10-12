# LevelMates: armería (proyecto 6)

Pedido en chat el 2026-10-12 ("sigue"), dentro de la hoja de ruta de [sincronización v2](2026-10-12-levelmates-sync-v2-design.md). Las ideas vienen de las [notas de funciones](../../research/2026-10-12-guild-features-notes.md); no se copia código ni datos de otros addons.

## Por qué

No se puede ver el equipo de un compañero sin tenerlo delante e inspeccionarlo. Y las builds de talentos solo se ven entre jugadores de la misma clase.

## 1. Mi equipo

- **Cuándo se lee:**
  - al entrar;
  - con `PLAYER_EQUIPMENT_CHANGED` (esperando 1 s de calma);
  - fuera de combate (si estoy en combate, se lee al salir).
- **Qué se lee:** de los 19 huecos, el id del objeto y su **nivel de objeto**:
  - el nivel sale de `C_Item.GetDetailedItemLevelInfo`, o si no, del nivel de `GetItemInfo`;
  - también el encantamiento, del enlace (`item:id:enchant`).
- **Nivel de objeto medio:** lo calculamos nosotros, sobre los 17 huecos que cuentan (sin camisa ni tabardo) y **solo los ocupados**, redondeado. En Forever, `GetAverageItemLevel` divide siempre entre 16.
- **Compartir:** estado personal `eq` (el mecanismo común de datos personales). Campos:
  - `g` = "hueco:id:nivel:encantamiento,…", en trozos si hace falta;
  - `a` = la media;
  - `r` = la raza y `x` = el sexo, para el modelo.

  Va con el interruptor nuevo "Compartir mi equipo" (activado), solo cuando cambia y a quien entra, como mucho una vez cada 10 minutos a recién llegados.

## 2. En la ficha del compañero

- **Una línea:** "Nivel de objeto 23 (14/17)".
- **Un botón "Equipo"** que abre una ventana pequeña con el estilo de libro:
  - **el muñeco:** los huecos en dos columnas y abajo las armas, como en la ventana de personaje; cada hueco con el icono del objeto, borde del color de su calidad y su descripción al pasar el ratón; los vacíos, con la silueta del juego;
  - **en medio, el modelo 3D** (`DressUpModel`):
    - si la persona está a la vista o en el grupo, `SetUnit`;
    - si no, `SetCustomRace(raza, sexo)`, `Undress()` y `TryOn` con cada objeto;
    - sin raza o sexo conocidos, no hay modelo;
  - **arriba:** nombre, nivel, la media y "visto hace…".
- En **Compañeros**, la descripción emergente de la fila suma la media.

## 3. Builds de todas las clases

- **Hasta ahora** solo se guardaban y veían las builds de mi clase.
- **Ahora** se guardan todas, y la ficha de cualquier compañero muestra su build (puntos por rama) con "Ver build". Ese botón usa el enlace `talentbuild` que el propio juego sabe abrir para cualquier clase. No hace falta un visor propio.
- La pestaña **Clase** sigue mostrando solo las de mi clase, que es para lo que sirve.

## 4. Mensajes

| Tipo | Clase | Campos |
|---|---|---|
| `eq` | personal | `g` (hasta 600: 19 × `hh:iiiiii:nnn:eeee`), `a` (int 0–999), `r` (int 1–100), `x` (int 2–3) |

## 5. Fuera de este proyecto

- **Inspeccionar** a quien no use LevelMates: necesita tenerlo delante y el juego lo limita. Si hace falta, más adelante.
- **Lista de "mejor en su hueco"** e historial del nivel de objeto: es más de banda que de subir de nivel (proyecto 8).
- **Visor de talentos propio:** el enlace del juego ya lo abre.

## 6. Pruebas

- **Lectura:**
  - 19 huecos simulados, con algunos vacíos;
  - la media sobre 17 y solo los ocupados;
  - el encantamiento del enlace;
  - en combate se espera a salir;
  - varios cambios seguidos dan una sola lectura.
- **Compartir:**
  - ida y vuelta del formato;
  - interruptor apagado, nada;
  - a quien entra, como mucho una vez cada 10 minutos.
- **Ficha:**
  - la línea con la media;
  - el botón abre la ventana;
  - los huecos con su objeto;
  - el modelo con raza y sexo (o sin modelo si faltan).
- **Builds:** la ficha de un compañero de otra clase muestra su build y "Ver build"; la pestaña Clase sigue solo con la mía.
