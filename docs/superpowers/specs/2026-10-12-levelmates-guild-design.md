# LevelMates: la hermandad (proyecto 5)

Pedido en chat el 2026-10-12 ("ok"), dentro de la hoja de ruta de [sincronización v2](2026-10-12-levelmates-sync-v2-design.md). Las ideas vienen de las [notas de funciones](../../research/2026-10-12-guild-features-notes.md); no se copia código ni datos de otros addons.

Sale en la **0.4.0**, con los proyectos 1 a 4.

## Por qué

- **Notas y mensaje del día:** en Forever, un addon no puede escribir las notas de la hermandad ni el mensaje del día.
- **Historial:** la hermandad no sabe quién entró, quién se fue ni quién subió de rango.
- **Alts:** cada uno los comparte, pero no hay una vista de "quién es quién".
- **Subir de nivel:** no hay forma de vivir la subida como una carrera común.
- **Banco:** nadie sabe qué hay en el banco sin ir a verlo.

## 1. Pestaña nueva: "Miembros" (dentro de Hermandad)

Una sub-pestaña nueva con cuatro vistas (botón para cambiar, como en Grupos): **Lista**, **Historial**, **Alts** y **Carrera**.

### 1.1 Lista

- **Todos los miembros** de la hermandad, de la lista del juego, no solo los que tienen el addon.
- **Columnas:** nombre (con el icono de rango para el líder y los oficiales), nivel, rango, zona o "visto hace…", y la **nota compartida**.
- **Filtros:** Todos / Conectados / Oficiales / Sin nota.
- **Pulsar a alguien:** susurrar, invitar, la ficha si usa LevelMates, y "Escribir nota" si puedo.

### 1.2 Notas compartidas y mensaje del día propio

- **Nota** (registro de tablón `gn`, id = `NameKey(destinatario)`, campos `f` = nombre completo del destinatario y `n` = texto de hasta 120 caracteres):
  - cualquiera puede escribir **la suya**;
  - quien tenga el permiso del juego para notas públicas (`CanEditPublicNote()`), la de **cualquiera**;
  - gana la más nueva, y se guarda quién la escribió;
  - un texto vacío borra.
- **Mensaje del día propio** (registro de tablón `gmo`, id `"motd"`, `n` hasta 180 caracteres):
  - lo escribe quien tenga el permiso del juego para el mensaje del día (`CanEditMOTD()`);
  - sale **arriba de Inicio** con su autor y cuándo;
  - aviso al cambiar (avisos de metas).
- Las dos cosas pasan entre todos y llegan a quien entra después.

### 1.3 Historial

- Se compara la lista de la hermandad con la anterior (al recibir `GUILD_ROSTER_UPDATE`, esperando a que haya calma 2 s). Eventos:
  - **entra** (nombre nuevo);
  - **sale** (ya no está; no se distingue "se fue" de "lo echaron");
  - **sube de rango** o **baja de rango** (cambia el índice de rango);
  - **sube de nivel**, solo a partir del nivel 10, para no llenarlo.
- **La primera vez** solo guarda la foto inicial, sin eventos. Lo que ya estaba sale como "conocido desde [fecha]".
- **Protecciones:**
  - una lista incompleta (menos filas que `GetNumGuildMembers()`) nunca genera salidas;
  - si desaparecen más de 5 y más de la mitad a la vez, se espera a la siguiente lectura para confirmarlo.
- Se guardan **las últimas 500 entradas** por hermandad.
- Es local: cada cliente ve lo que ha visto. No se envía nada.
- **Al muro** van las entradas y salidas (no los niveles, que el muro ya tiene).

### 1.4 Alts

- Un árbol: cada **principal** con sus alts debajo. El principal es el de más nivel, salvo que esa persona elija otro.
- **La fuerza del enlace:**
  - **comprobado:** mismo ordenador (mis personajes, por los datos de la cuenta);
  - **declarado:** lo dice la propia persona con su `al` actual.
- Los que no tienen alts conocidos salen solos.

### 1.5 Carrera al 60

- **Clasificación:** conectados y vistos en 30 días, por nivel; a igual nivel, el que llegó antes.
- **Primeros:**
  - "**Primero en llegar al 60**" de la hermandad;
  - "**primero de cada clase**".

  Solo cuentan las llegadas **vistas en directo** (por latido o por la lista de la hermandad mientras estaba conectado). Los que ya estaban a 60 cuando empezamos a mirar salen como "ya estaba".
- Una llegada al 60 en directo va **al muro** y da aviso (avisos de niveles).

## 2. Pestaña nueva: "Banco" (dentro de Hermandad)

- **Lectura:** quien **abre el banco** lo lee.
  - Se piden las pestañas que puede ver, una cada 0,4 s, y se leen tras 1,2 s de calma.
  - De cada pestaña: nombre, icono y objetos (id y cantidad, sumando montones iguales).
  - También el oro.
  - Una pestaña que no ha cargado conserva lo anterior.
- **Compartir:** al cerrar el banco se envía la foto (registro de tablón `gbk`, id `"bank"`, en trozos):
  - `t` = fecha de la foto;
  - `m` = oro;
  - `p` = pestañas en el formato `nombre~id:n,id:n|…`, con `~`, `,` y `|` quitados de los nombres.

  Gana la más nueva. Una foto con fecha de más de 5 minutos en el futuro se rechaza. Interruptor nuevo: "Compartir el banco al abrirlo" (activado).
- **Vista:**
  - una fila por objeto (enlace, cantidad y pestaña);
  - el buscador de siempre filtra;
  - arriba, "Banco de [quién] · hace … · oro".

## 3. Mensajes nuevos

| Tipo | Clase | Campos | Notas |
|---|---|---|---|
| `gn` | tablón | `f` (destinatario, 48), `n` (120, vacío = borrar) | id = `NameKey(f)`; puede cambiarla el propio destinatario o quien tenga permiso de notas |
| `gmo` | tablón | `n` (180) | id `motd`; solo quien tenga permiso del mensaje del día |
| `gbk` | tablón | `t`, `m`, `p` (largo) | id `bank`; gana la más nueva |

El permiso del que escribe se comprueba **en quien recibe**: las notas de otro o el mensaje del día solo se aceptan de un oficial según la lista de la hermandad (rango de líder u oficial), porque el permiso del juego solo se puede preguntar por uno mismo.

## 4. Fuera de este proyecto

- Ascender, degradar, invitar o expulsar con botones: el juego protege esas acciones, y quedan para la interfaz (proyecto 7) si hacen falta.
- Chat de hermandad dentro del libro: no aporta frente al chat del juego.

## 5. Pruebas

- **Notas:**
  - la mía;
  - la de otro sin permiso se rechaza y con permiso de oficial se acepta;
  - vacía borra;
  - llega a quien entra después (varios jugadores).
- **Mensaje del día:** solo de un oficial; sale arriba de Inicio.
- **Historial:**
  - la primera lectura no genera eventos;
  - entra, sale y cambia de rango;
  - una lista incompleta no genera salidas;
  - la protección ante bajadas masivas;
  - el tope de 500.
- **Alts:** el árbol con el principal de más nivel; comprobado frente a declarado.
- **Carrera:**
  - el orden;
  - el primero al 60 en directo frente a "ya estaba";
  - el primero de su clase;
  - al muro.
- **Banco:**
  - lectura con pestañas simuladas y la espera de calma;
  - el formato de ida y vuelta;
  - el rechazo de fechas futuras;
  - la vista con el buscador;
  - llega a quien entra después.
