# Botín de banda: libro, reparto y sesiones — diseño

Proyecto 8. Fecha: 2026-10-16. Pedido por el usuario: "vayamos con la fase de DKP", "hazlo para varias formas" (DKP, reserva suave, consejo/+1, tiradas) sobre una base común. Se diseña con lo aprendido de Guild Armory 0.1.58 (leído, no copiado) y con nuestras propias medidas en Forever.

## Lo que sabemos de Forever (y condiciona todo)

- Dentro de una instancia, un mensaje de addon por **hermandad** vuelve bloqueado (código 11): medido por nosotros (sincronización v2).
- Durante un **combate de jefe** los mensajes de addon se pierden en silencio y el chat de addon está bloqueado (Guild Armory, 13.10.2026). Entre jefe y jefe, Guild Armory usa el canal de **banda/grupo** para sesiones y **susurros** para respuestas, pero nunca midió que funcione dentro de la instancia.
- El registro de combate está cerrado a los addons. El jefe se conoce por `ENCOUNTER_START/END` (si disparan) y por el cadáver de la ventana de botín (`GetLootSourceInfo`).
- El método de botín llega como número (`C_PartyInfo.GetLootMethod`); el global `GetLootMethod` no existe. Las sesiones solo tienen sentido con **botín maestro**.
- GUIDs y nombres pueden ser valores secretos: toda comparación pasa por `ns.Same`, toda lectura por `ns.Plain`.

## Decisiones

1. **Medir antes de prometer pujas en vivo.** `/lm sondabanda`: dentro de una instancia y fuera de combate, envía un mensaje de prueba por banda o grupo y uno por susurro a mí mismo, apunta los códigos que devuelve el servidor, si llega el eco, y el estado de bloqueo que informa el cliente. El resultado va al chat y a `/lm informe`. Hasta tener la medida, nada depende del canal de banda.
2. **Una base que funciona midan lo que midan:** el libro y el historial viven en registros del tablón sincronizados por hermandad **fuera** de las instancias; dentro, el maestro despojador captura en local y todo sale al salir (la retención de la capa de mensajes, ampliada a 4 horas para este tipo).
3. **Libro de apuntes, solo-añadir.** Un apunte: quién, puntos (±), tipo (asistencia, jefe, gasto, ajuste, devolución), motivo, banda, objeto (si lo hay), autor, hora. El saldo es la suma; nada se edita ni se borra: un error se corrige con un apunte contrario que apunta al original. Escriben solo los oficiales (o el maestro despojador de esa banda). Todos lo ven.
4. **Historial de botín con grado de prueba.** Cada asignación guarda el jefe (evento o cadáver; si no, "desconocido", nunca adivinado), el objeto, el receptor decidido por el maestro despojador y cómo se confirmó la entrega: reparto maestro desde un clic (fuerte), intercambio completado (fuerte), línea del chat de botín (débil), a mano (débil). Estados: asignado → entregado → equipado; cancelado; corregido (el nuevo apunta al viejo).
5. **Varios modos sobre la misma sesión.** Una sesión es del maestro despojador y tiene objetos; cada respuesta de un jugador es una fila: respuesta de consejo (principal, mayor, menor, pasar, con nota), puja DKP sellada, rango de tirada (100/50/25) o marca de reserva. El modo y sus reglas viajan con la sesión. Si la sonda confirma el canal de banda, la sesión va en vivo; si no, la misma ventana del maestro despojador se rellena a mano con lo que la gente canta por el chat.
6. **Reserva suave:** una ronda por noche abierta por el maestro despojador, caduca a las 8 horas, límite de reservas por persona configurable (2). Cada uno reserva lo suyo (el remitente lo pone el servidor), o el maestro pega una lista. Pasarse del límite o reservar lo mismo que otro se ve, no se impide. Al caer el objeto, la tarjeta muestra a quienes lo reservaron; entre ellos decide una tirada.
7. **+1:** no se guarda; se calcula de las asignaciones entregadas de calidad épica o mayor, por jugador (sus alts cuentan, con `Alts`).
8. **Asistencia:** en el cliente del maestro despojador, una foto del grupo en cada `ENCOUNTER_END` con victoria y otra al cerrar la banda; apuntes de asistencia y de jefe con los puntos que marquen las reglas (0 si no se quiere DKP).
9. **Nada sale sin clic:** abrir sesión, asignar, apuntar puntos y publicar saldos en Discord son clics. Ningún susurro ni línea de chat automática.

## Pantallas

- **Hermandad → Botín**, tres vistas: **Saldos** (nombre, puntos, ganados, gastados, último apunte; clic → su historial; oficiales: apunte manual con motivo, a uno o a todo el grupo presente), **Historial** (cuándo, objeto, receptor, jefe, prueba, estado; búsqueda; corregir/cancelar para oficiales), **Reservas** (la ronda abierta: quién reserva qué; añadir la mía; el maestro cierra o abre).
- **Ventana del maestro despojador**: una tarjeta por objeto con los candidatos (del grupo), lo que aporta cada modo (saldo y puja, reserva, +1, deseo, nivel de objeto actual en esa ranura) y "Asignar a…". "Copiar saldos para Discord".
- **Tarjeta de respuesta** (jugador), solo si la sonda lo permite: el objeto comparado con lo que lleva, los botones del modo y "Pasar".
- **Reglas** (oficiales, en Opciones → Botín): modo por defecto, puntos por jefe y por asistencia, puja mínima, límite de reservas, calidad mínima que se registra (azul).

## Registros y mensajes

- `lk` (board, oficiales, vida 365 d): un apunte del libro. `la` (board, 180 d): una asignación del historial, con sus cambios de estado como apuntes propios. `lr` (board, 8 h): una reserva. Todos por hermandad, con retención dentro de instancias.
- Sesión en vivo (solo si la sonda lo permite): `ls` abrir/cerrar, `li` objeto, `lb` respuesta de un jugador (por susurro al maestro), `lw` asignación; por banda/grupo, con comprobación de bloqueo antes de cada envío y reintento a los 30 s con código 11; caducan a los 10 minutos.

## Medido el 2026-10-16 (sonda)

Dentro de una mazmorra, en grupo y fuera de combate: los mensajes de addon por PARTY y por susurro vuelven con código 0 y el eco llega; el cliente no informa bloqueo. Solo el canal de hermandad está bloqueado (11). Decisión 5 resuelta: las sesiones van en vivo por el canal de grupo (ls/lb/lw/lc en LootSession.lua), con retención y reintento ante el código 11, y la tarjeta de respuesta (LootCard.lua). En combate de jefe se pierden, como ya se sabía: el botín llega después.

## Fuera de alcance

Planes de banda, avisos por voz, estadísticas de botín (más adelante), DKP por "main" (los alts se agrupan solo para el +1).

## Pruebas

Todo con el simulador (`tests/*.test.lua`): el libro (sumas, correcciones, permisos), el historial (estados, pruebas, duplicados por cadáver y ranura en una hora), la captura (encuentro, cadáver, reparto por clic, intercambio, línea de chat), la retención dentro de instancias, las reservas (límite, caducidad, remitente del servidor), el +1, las vistas y la sonda (códigos y eco). En el juego: la sonda en una mazmorra, una banda real con botín maestro.
