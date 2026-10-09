# LevelMates: metas

Última parte de la pieza 3 de 4 (metas, diario y XP descansada). Se implementa en dos planes: **A**, metas de hermandad (nivel para todos, mazmorra juntos, contador); **B**, metas personales. Se apoya en el roster, el diario, la pestaña del tablón y la política de v1.

## 1. Objetivo

Que la hermandad se marque objetivos comunes mientras sube de nivel y vea el progreso de todos, y que cada uno pueda enseñar su propio objetivo. Éxito: un oficial crea "todos a nivel 30 antes del viernes" y cualquier hermano con el addon ve la barra y quién falta, aunque el oficial ya no esté conectado.

## 2. Tipos

| Tipo | Ejemplo | Progreso | Quién la crea |
|---|---|---|---|
| Nivel para todos | todos a nivel 30 antes del viernes | hermanos con el addon que llegaron / hermanos con el addon conocidos; lista de quién falta | oficiales y maestro |
| Mazmorra juntos | Minas de la Muerte antes del domingo | hecha / no hecha, y por quién | oficiales y maestro |
| Contador | 100 niveles entre todos esta semana (o misiones, o mazmorras) | suma de lo que aporta cada hermano desde que empezó | oficiales y maestro |
| Personal | yo, nivel 40 el domingo | mi nivel actual frente al objetivo | cada uno, solo la suya |

Límites: 5 metas de hermandad activas; 1 personal por personaje. Una meta caduca 2 días después de su fecha límite y se borra sola.

## 3. Quién es oficial

Se usa el rol de comunidad de la hermandad que da el juego (`C_Club`): **Owner** (maestro) o **Leader** (oficial), el mismo criterio que usa la interfaz de Blizzard para sus permisos de gestión. Para mí: `IsGuildLeader()` o `C_GuildInfo.IsGuildOfficer()`. Para quien envía un mensaje: su rol en la lista de miembros de la hermandad (`C_Club.GetMemberInfo`). Un mensaje de crear o borrar meta de alguien que no es oficial, o que no está en la lista, se ignora.

## 4. Mensajes

Tipos nuevos (las versiones anteriores los ignoran):

| kind | Qué | Campos |
|---|---|---|
| `go` | una meta de hermandad | `id` (palabra ≤ 8), `ty` (`lvl`, `dun` o `cnt`), `a` (entero: nivel objetivo, id de mazmorra o cifra objetivo), `w` (para `cnt`: `lvl`, `qst` o `dun`), `s` y `e` (día de inicio y día límite, días desde 1970) |
| `gx` | borrar una meta | `id` |
| `gd` | mazmorra juntos hecha | `id` |
| `gc` | mi aportación a un contador | `id`, `n` (entero 0-10000) |
| `gp` | mi meta personal (plan B) | `l` (nivel objetivo, 0 = la quito), `e` (día límite) |

Reglas de difusión:
- Al crear o borrar, quien lo hace lo envía.
- A quien acaba de conectarse, justo después de mi latido: las metas de hermandad que guardo **si soy oficial o soy quien la creó**; mi aportación a cada contador; mi meta personal. Así un recién llegado recibe las metas aunque su creador esté desconectado, mientras haya algún oficial conectado.
- `gd` lo envía el primero cuyo diario registra la mazmorra con al menos otro hermano en el grupo, y solo si la meta sigue sin hacer.
- `gc` se envía cuando cambia mi aportación (después de un latido, como mucho una vez por minuto) y al responder a un recién llegado.
- Nada dentro de instancias; nada sin "Aparecer en el tablón".

## 5. Guardado

- Por cuenta y por hermandad: `ns.db.goals[hermandad][id]` con la definición, las aportaciones de cada uno (`gc`) y, si es de mazmorra, quién la hizo. Así siguen al reconectar o cambiar de personaje.
- Niveles conocidos: `ns.db.seen[hermandad][nombre] = { nivel, cuándo }`, actualizado con cada latido recibido, para que "nivel para todos" cuente también a quien no está conectado ahora. Se olvidan los no vistos en 30 días.
- Mi aportación a un contador se calcula desde mi diario: entradas del tipo correspondiente con fecha posterior al inicio de la meta.

## 6. Interfaz

- Cuarta pestaña **"Metas"** en el tablón. Las cuatro pestañas de abajo pasan a 70 de ancho.
- Lista: metas de hermandad arriba (texto, progreso "12/20" o "Hecha por Ana", fecha límite), personales debajo (nombre, objetivo, nivel actual, fecha).
- Al pasar el ratón por una meta de nivel: quién falta.
- Botón **"Nueva meta"** (solo oficiales): cuadro con tipo, objetivo (nivel, mazmorra de la lista o cifra), qué cuenta el contador, y plazo (1, 3, 7 o 14 días).
- Botón **"Borrar"** en el menú del clic derecho sobre una meta, solo para quien la creó y oficiales.
- Botón **"Mi meta"** (plan B): nivel objetivo y plazo; "Quitar mi meta" si ya hay una.
- Aviso en el chat cuando se crea una meta de hermandad y cuando una se cumple; opción para apagarlo.

## 7. Pruebas

- Formato de los cinco mensajes y sus rangos.
- Oficiales: crear y borrar solo con rol Owner o Leader; mensajes de no oficiales ignorados; límite de 5.
- Difusión a un recién llegado después del latido, solo desde oficiales o el creador.
- Progreso de nivel con conectados y desconectados vistos; quién falta; olvido a los 30 días.
- Mazmorra juntos: hecha al registrarse en el diario con un hermano; no sin hermano; solo una vez.
- Contador: aportación desde el diario, suma de todos, envío con el latido limitado.
- Caducidad a los 2 días de la fecha límite.
- Pestaña, cuadro de nueva meta, borrado y avisos.
- Personal (plan B): crear, quitar, ver la de otros, caducidad.
- Simulación `/lm sim metas`.

## 8. Riesgos

- El rol de oficial con `C_Club` en Forever se comprueba en el juego.
- "Quién falta" solo conoce a quien el addon ha visto alguna vez.
- Si no hay ningún oficial ni el creador conectados, un recién llegado no recibe las metas hasta que uno se conecte.
