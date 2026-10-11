# LevelMates: el libro de la hermandad (aspecto, 5 pestañas, Inicio y progreso)

Aprobado en chat el 2026-10-11 (partes 1 y 2: "yes", "ok").

## Por qué

La hermandad se lía con LevelMates: al abrirlo no sabe qué hacer, hay nueve pestañas y todo son tablas lisas. Objetivo: que se vea mejor, que enganche (progreso común con rankings suaves) y que no líe.

## 1. Aspecto: el libro de la hermandad

Inspirado en "What's Training?" sobre el libro de hechizos de Forever. Solo arte del propio juego (atlas de Forever), nada de otros addons.

- Marco del juego (ButtonFrameTemplate) **con retrato**: el icono de LevelMates (o el estandarte de la hermandad si el cliente lo da).
- Pestañas: **5 iconos cuadrados** arriba (marco `spellbook-Tab-Frame-C60`), tooltip con el nombre, la activa iluminada. Buscador a la derecha de la barra superior.
- Página de **pergamino** (`spellbook-Page-Right-C60` / `-Left-C60`): título grande en letra decorativa del juego, línea ornamental `spellbook-divider` debajo.
- **Marcapáginas** `spellbook-background-evergreen-ribbon` colgando a la derecha.
- **Secciones**: franja oscura translúcida con texto en color y número ("Conectados • 3"). Verde = ahora, amarillo = pronto, azul = información, gris = otros.
- **Filas**: icono, texto oscuro sobre pergamino, línea fina de separación; nombres en color de clase oscurecido para leerse sobre papel.
- **Pista abajo** en cada página: qué se puede hacer ("Clic: ficha · Clic derecho: invitar o susurrar").
- Tarjetas de mazmorra como ahora (imagen completa), sobre el pergamino.
- Las ventanas pequeñas (ficha, Discord, quedada, deseos, metas, preguntas) con el mismo pergamino.
- Se **quita la opción de estilo clásico** (un solo aspecto que mantener).

## 2. Estructura: 5 pestañas

| Pestaña | Contenido |
|---|---|
| Inicio | "¿Qué hago ahora?" (sección 4) |
| Hermanos | el tablón y las fichas |
| Mazmorras | tarjetas, grupos, calendario |
| Hermandad | subsecciones con botón-icono en la página: Muro · Metas y logros · Mercadillo y deseos · Oficios · Clase · Reclutar (solo oficiales) |
| Diario | lo personal: diario, mi meta, (fase 2) mis logros |

Al abrir siempre se entra en Inicio. Los comandos `/lm metas`, `/lm oficios`, `/lm clase`, etc. siguen abriendo su sitio.

## 3. Progreso de la hermandad

Cada uno cuenta **sus** puntos y los comparte (como las profesiones); la hermandad suma los de todos los que se han visto en 30 días y siguen en la hermandad.

**Puntos** (se cuentan en el propio ordenador, al ocurrir):

| Acción | Puntos |
|---|---|
| Subir de nivel | 10 |
| Terminar una mazmorra con hermanos | 15 |
| Ir a una quedada (estar en grupo con su creador a su hora) | 10 |
| Ayudar ("Voy" en una petición de ayuda) | 5 |
| Regalar o vender en el mercadillo (reserva confirmada por mí) | 5 |
| Entregar una misión | 1 |

**Mensaje** `pt` (último estado gana): `t` = puntos totales, `w` = semana (número de semana desde 1970, lunes a domingo, hora del servidor), `l`, `d`, `h`, `q` = niveles, mazmorras, ayudas y misiones de esa semana. Se envía al cambiar (como mucho una vez por minuto), al anunciarse y a quien se conecta.

**Nivel de la hermandad**: suma de `t`. El nivel N cuesta `100 * N` puntos más que el anterior (1→2: 100, 2→3: 200…). Barra hasta el siguiente. Al subir, aviso y entrada en el muro.

**Reto de la semana**: rota solo según el número de semana, de una lista fija (25 mazmorras, 60 niveles, 15 ayudas, 200 misiones…; la meta escala con cuántos hermanos se han visto esa semana). Progreso = suma de lo de esa semana de todos. Al cumplirlo, aviso y entrada en el muro (una vez).

**Rankings suaves**: los 3 primeros de la semana en niveles, mazmorras y ayudas. Nunca quién va último.

Opción "Compartir mis puntos" (sí): apagada, no cuento en la hermandad ni en rankings.

## 4. Inicio

De arriba abajo:
1. **La hermandad**: nombre, nivel y barra; reto de la semana y su barra.
2. **Ahora mismo**: peticiones de ayuda (botón "Voy"), grupos de mazmorra abiertos ("Me apunto"), quedadas de hoy.
3. **Para ti**: hermanos conectados a ±3 niveles o en tu zona ("Invitar"); alguien regala o vende algo de tus deseos; hechizos esperando en el entrenador.
4. **Esta semana**: los rankings.
5. Si no se ve a nadie: "Tus hermanos necesitan LevelMates para salir aquí" y un botón que copia un mensaje de invitación (para chat o Discord; nunca se envía solo).

Cada sección vacía se oculta, salvo la de la hermandad.

## Fase 2 (fuera de esta especificación)

Logros personales (colección de hitos visibles en la ficha y en el Diario).

## Aparte

"Pedir ayuda no funciona": se investiga como fallo antes de empezar esta obra.

## Pruebas

Cuenta de puntos por acción y su envío; suma, nivel y caducidad de 30 días; semana y reto (rotación, escala, cumplido una vez); rankings (top 3, sin últimos); Inicio (secciones, ocultar vacías, mensaje sin hermanos); 5 pestañas y subsecciones; comandos que abren su sitio; aspecto (atlas, retrato, marcapáginas, pista).
