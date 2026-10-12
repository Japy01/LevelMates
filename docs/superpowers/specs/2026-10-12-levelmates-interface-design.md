# LevelMates: interfaz (proyecto 7)

Pedido en chat el 2026-10-12 ("sigue"), dentro de la hoja de ruta de [sincronización v2](2026-10-12-levelmates-sync-v2-design.md). Las ideas vienen de las [notas de funciones](../../research/2026-10-12-guild-features-notes.md); no se copia código ni datos de otros addons.

## Por qué

- **Respuestas que se pierden:** cada clic responde en el chat, donde se mezcla con todo lo demás.
- **Borrados sin red:** varias acciones que borran no piden confirmación.
- **Avisos que se escapan:** se pierden si no miras el chat en ese momento.
- **Subir de nivel:** no hay una barra con XP por hora y tiempo hasta el siguiente nivel, ni un momento especial al subir.

## 1. Barra de mensajes en el libro

- Lo que hoy dice el addon tras un clic ("Invitados 3…", "Publicada…", "No se pudo…") sale **en una línea al pie del libro** si está abierto: 6 segundos y luego se desvanece. Si no está abierto, va al chat como ahora.
- **Color:** verde (hecho), naranja (aviso) o rojo (no se pudo).
- **Pulsar la línea** la cierra.
- Usa los mensajes que ya existen. Cambia **dónde** salen, no **qué** dicen.

## 2. "¿Seguro?"

- **En los botones** que borran algo:
  - el primer clic cambia el texto a "¿Seguro?" en rojo;
  - un segundo clic en 5 segundos lo hace;
  - si no, el botón vuelve a su estado.
- **En los menús** (que se cierran al pulsar), una ventana del juego: "¿Seguro que quieres cancelar la partida?" con Sí/No.
- **Acciones:**
  - cancelar una partida;
  - retirar una misión del tablón;
  - borrar una meta;
  - quitar un deseo o una oferta del mercadillo;
  - quitar a alguien de tu partida.

## 3. Avisos: bandeja y tira bajo el minimapa

- **Todo aviso** (los de `ns.Notice`) se guarda también en una **bandeja**: los últimos 30, como mucho de 2 horas.
- **El botón del minimapa** muestra un **número** con los no leídos.
- **Una tira bajo el minimapa** enseña el último aviso durante 10 segundos:
  - en combate espera, y al salir enseña solo el último;
  - los primeros 20 segundos tras entrar no sale (la puesta al día llega en esos segundos).
- **Abrir la bandeja:** pulsar la tira, o Mayús+clic en el botón del minimapa.
- **En la bandeja:**
  - una fila por aviso, con su hora y, si tiene, un botón de acción (abrir la pestaña que toca: Grupos, Misiones, la ficha…);
  - abrirla marca todo como leído.
- **Interruptores** en Opciones > Avisos:
  - "Tira bajo el minimapa" (activado);
  - el modo tranquilo existente la apaga también.

## 4. Barra de nivel

- Una barra pequeña que se puede **mover y bloquear**, apagada por defecto. Se activa en Opciones > General o con `/lm barra`.
- **Muestra:**
  - nivel;
  - % de XP con la parte descansada marcada;
  - **XP por hora** (ventana móvil de 15 minutos);
  - **tiempo hasta el siguiente nivel**;
  - tiempo en este nivel;
  - muertes de enemigos en este nivel (contadas del mensaje de XP del chat, comparado con el patrón del propio cliente).
- **Descripción emergente:** el detalle de cada dato.
- Se recuerda la posición por personaje.

## 5. Al subir de nivel

Un **cartel** de unos 8 segundos (estilo libro, sobre la pantalla):
- "¡Nivel 24!";
- el tiempo que llevó el nivel;
- la XP por hora de ese nivel;
- tu puesto en la **carrera** de la hermandad, si la hay.

Se cierra al pulsarlo. Interruptor en Opciones > Avisos (activado). El modo tranquilo lo apaga.

## 6. Fuera de este proyecto

- **Buscador en Opciones:** el panel de opciones del juego ya trae su propio buscador.
- **Pestañas ocultables:** el libro tiene cinco pestañas; no hace falta.
- **Recolección** (marcar hierbas y minerales): va con las hogueras, porque necesita datos del juego que sacaremos en Forever.
- **Ocultar el libro en combate:** no tiene botones protegidos; no hace falta.

## 7. Pruebas

- **Barra de mensajes:**
  - con el libro abierto, sale al pie y se va a los 6 s;
  - con el libro cerrado, sale en el chat;
  - colores por tipo.
- **"¿Seguro?":**
  - primer clic, sin hacer nada;
  - segundo en 5 s, hecho;
  - a los 6 s, el botón vuelve;
  - los menús piden confirmación.
- **Bandeja:**
  - un aviso queda en la bandeja;
  - el número del minimapa;
  - la tira 10 s;
  - en combate espera;
  - los primeros 20 s no;
  - abrir la bandeja marca leído;
  - el tope de 30 y de 2 h.
- **Barra de nivel:**
  - la XP por hora con muestras simuladas;
  - el tiempo hasta subir;
  - las muertes contadas del mensaje;
  - apagada por defecto;
  - `/lm barra`.
- **Cartel:**
  - al subir, con los datos del nivel;
  - se cierra al pulsar;
  - apagado en modo tranquilo.
