# LevelMates: grupos unificados (proyecto 9)

Pedido en el juego el 2026-10-13, al probar la 0.4.0:
- "Buscar grupo ahora" y "Partidas" se ven como cosas distintas y raras.
- El panel de una mazmorra es feo.
- En Inicio no sale quien busca grupo ahora, ni tu propio anuncio.
- Hay que poder anunciar algo más que mazmorras: bandas, JcJ (campos de batalla y JcJ de mundo) u otras cosas.

## La idea: todo es un **grupo**

Un grupo tiene:
- **qué**: una actividad del catálogo o un texto libre;
- **cuándo**: **Ahora**, o un día y una hora;
- **tamaño** y **plazas por rol**;
- un **líder**;
- una nota.

Lo de hoy pasa a ser:

| Hoy | Pasa a ser |
|---|---|
| "Buscar grupo" (anuncio inmediato) | un grupo **Ahora** |
| "Partida" / quedada | un grupo con día y hora |

**Por dentro**, siguen los dos mensajes que ya sincronizan:
- el anuncio inmediato (`lfg`/`lfj`) para Ahora;
- el registro de partidas (`qd`/`qj`/`qm`) para los que tienen hora.

Los dos ganan los mismos campos, y la interfaz los muestra igual. La 0.4.0 no se ha publicado, así que no hay compatibilidad que guardar con nadie.

## Tipos y catálogo

| Tipo | Actividades | Tamaño | Plazas |
|---|---|---|---|
| **Mazmorra** | las 14 del diario de Forever (ids 1–14, sin cambios) | 5 | 1 tanque, 1 sanador, 3 daño |
| **Banda** | las de Vanilla que haya (ids 101+: Núcleo de Magma, Onyxia, Zul'Gurub, Guarida Alanegra, Ruinas y Templo de Ahn'Qiraj, Naxxramas) y **banda libre** (nombre escrito: "Jefe de mundo: Azuregos") | 10, 20 o 40 | 10 → 2/3/5 · 20 → 3/5/12 · 40 → 5/10/25 |
| **JcJ** | Garganta Grito de Guerra (10), Cuenca de Arathi (15), Valle de Alterac (40) (ids 201+) y **JcJ de mundo** (nombre escrito) | el del campo; en el de mundo, 5–40 | sin roles: "cualquiera" |
| **Otro** | texto libre ("misión élite Stromgarde", "farmear Tejido de seda") | 2–40 | sin roles |

**Cómo se ajusta:**
- El líder puede cambiar el reparto de una banda.
- Si el servidor no tiene una actividad del catálogo, se quita de la lista; el texto libre siempre está.
- El nombre libre tiene como mucho 40 letras y pasa por el mismo filtro que las notas.

**Campos nuevos** en `lfg` y en `qd`:
- `d`: id de la actividad (los de mazmorra no cambian);
- `x`: tamaño, cuando no es el de la actividad;
- `c`: plazas por rol, cuando no son las de por defecto (`T2H3D5`);
- `t`: nombre libre.

Para los grupos sin roles se usa el rol `A` ("cualquiera"). Un mensaje sin `d` conocido y sin `t` se ignora, como ahora.

## Lo que se ve

### La sección "Grupos" (antes "Mazmorras")

Tiene dos vistas, con dos botones claros abajo: **Grupos** y **Catálogo**. Juntos y Misiones siguen como hoy.

**Vista Grupos** (la principal):
- **A la izquierda:**
  - **Ahora**: los grupos que buscan gente ya, el mío incluido;
  - **Hoy y mañana**: los grupos con hora;
  - **Más adelante esta semana**: una lista;
  - **Anuncios del chat**: lo leído en Comercio y General, como lista.
- **Las tarjetas:**
  - un grupo de 5 o menos muestra sus **casillas** (icono de clase o de rol);
  - uno más grande muestra **contadores por rol** con barritas ("Tanques 2/5 · Sanadores 4/10 · Daño 12/25");
  - sin roles: "12/40";
  - al pulsar la tarjeta se ve quién va.
- **Los botones de la tarjeta:**
  - Unirme (con los roles libres);
  - Salir;
  - Invitar a todos (solo el líder);
  - Retirar o Cancelar, con "¿Seguro?".
- **A la derecha, el formulario "Crear grupo":**
  - **tipo** (chips Mazmorra / Banda / JcJ / Otro);
  - la actividad (desplegable) o el nombre libre;
  - el tamaño, si es banda, JcJ de mundo u otro;
  - **cuándo**: chips **Ahora**, Hoy, Mañana y los 5 días siguientes; la hora y los minutos solo si no es Ahora;
  - la nota;
  - mi rol (no sale si el grupo no tiene roles);
  - Discord;
  - **Publicar**.

**Vista Catálogo:**
- las tarjetas con imagen de antes, con tres chips: **Mazmorras / Bandas / JcJ**;
- en cada tarjeta, cuántos grupos tiene (ahora y con hora) y cuántos anuncios del chat;
- al pulsar una tarjeta se abre su panel.

### El panel de una actividad (rehecho)

- **Arriba**, la imagen y el nombre, con los niveles.
- **"Grupos"**: los de esa actividad, ahora y con hora, con las mismas tarjetas.
- **"Compañeros de su nivel"** conectados, con Susurrar e Invitar.
- **"Anuncios del chat"**, con Susurrar.
- **Abajo**, el botón **"Crear grupo aquí"**: lleva a la vista Grupos con el formulario ya rellenado con esa actividad.
- Todo en pergamino y tinta, como el panel de Inicio.

### Inicio

- **"Próximas partidas"** pasa a ser **"Grupos"**: primero los de Ahora (también el mío, con su botón Retirar) y después los siguientes con hora. Caben dos tarjetas.
- "Ahora" se queda con las ayudas y lo que es para mí: regalos y entrenador.

### Discord

El tipo va delante. Por ejemplo:
- `[LevelMates] Banda · Núcleo de Magma · vie 21:00 · líder X · faltan: 3 tanques, 6 sanadores, 13 daño`
- `[LevelMates] Ahora · Minas de la Muerte · líder X · faltan: sanador`

## Fuera de este proyecto

- **El botín y el DKP de las bandas**: proyecto 8, sobre estos mismos grupos.
- **El identificador para un bot de Discord**: aparte, cuando se decida.

## Pruebas

- **Catálogo:** los ids de mazmorra no cambian; las bandas y el JcJ con su tamaño y reparto; el nombre libre, filtrado y con límite.
- **Mensajes:**
  - un grupo con tipo, tamaño, reparto y nombre libre viaja entre dos clientes, Ahora y con hora;
  - unirse con rol, y con `A` sin roles;
  - un grupo lleno no admite más.
- **Tarjetas:** casillas hasta 5; contadores por encima; "12/40" sin roles.
- **Vista Grupos:**
  - las secciones Ahora / Hoy y mañana / Más adelante / Chat;
  - el formulario: Ahora publica al momento, con día y hora queda como partida;
  - el tamaño y el rol aparecen o se ocultan según el tipo.
- **Catálogo:** las tres pestañitas y sus recuentos.
- **Panel:** grupos, compañeros, anuncios y "Crear grupo aquí".
- **Inicio:** el mío Ahora aparece, con Retirar.
- **Discord:** la línea con el tipo.
