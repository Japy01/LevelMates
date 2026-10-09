# LevelMates: XP descansada

Primera parte de la pieza 3 de 4 (metas, diario y XP descansada) para la primera versión pública. Se apoya en el roster, el tablón, los mensajes por hermandad y la política de v1, igual que buscar grupo y compañero de leveo.

## 1. Objetivo

Que cada jugador vea de un vistazo cuánta XP descansada tiene, que sepa cuándo está al máximo, y que pueda ver la de los hermanos que decidan compartirla. Éxito: abro el tablón y veo "Descansada: 45%"; paso el ratón por un hermano que comparte y veo la suya.

## 2. Alcance

**Dentro:** mi XP descansada junto al título del tablón; aviso en el chat al llegar al máximo; opción para compartirla (apagada por defecto); la de los hermanos que comparten, en el texto al pasar el ratón por su fila; simulación con `/lm sim rested`.

**Fuera, a propósito:** columna propia en el tablón; ordenar o filtrar por XP descansada; historial; avisos sobre la XP descansada de otros.

## 3. Política y privacidad (heredadas de v1)

- Compartir la XP descansada es opcional y está **apagado por defecto**, como la posición y la XP/h.
- Requiere "Aparecer en el tablón" para enviar nada. Dentro de una instancia no se envía nada.
- Solo mensajes de addon a la hermandad.

## 4. Cálculo

- Porcentaje de un nivel: `redondeo(XP descansada / XP del nivel × 100)`, con `GetXPExhaustion()` (nil = 0) y `UnitXPMax("player")`.
- Tope: 150 % (1,5 niveles, regla de Classic; se comprueba en el juego y, si Forever usa otro, solo cambia la constante).
- A nivel máximo (`UnitLevel("player") >= 60`) no se muestra ni se comparte.

## 5. Lo mío

- Junto al título grande del tablón ("Hermanos conectados") sale "Descansada: 45%", en las dos pestañas. Se actualiza con `UPDATE_EXHAUSTION`, `PLAYER_UPDATE_RESTING`, `PLAYER_XP_UPDATE` y al abrir el tablón.
- Aviso en el chat "Tu XP descansada está al máximo (150%)." una vez por sesión, cuando llega al tope (incluido al entrar si ya estaba). Opción "Aviso de XP descansada al máximo" (activado por defecto). Sin sonido.

## 6. Mensaje

Un tipo nuevo, `rx`, con un campo `p` (entero de -1 a 200, obligatorio): el porcentaje, o `-1` para "ya no comparto". **No se añade al latido**: las versiones anteriores descartarían el latido entero (misma razón que en compañero de leveo).

Cuándo se envía, solo con "Compartir mi XP descansada" activo:
- Al activar la opción (y `p = -1` al desactivarla).
- Al entrar al mundo o recargar, y a quien acaba de conectarse, justo después de mi latido.
- Después de un latido, si el valor cambió 5 puntos o más desde el último envío y ha pasado al menos un minuto.
- `p = -1` con envío inmediato al apagar "Aparecer en el tablón".

Un `rx` de un nombre que el roster no conoce se ignora. El dato de un hermano desaparece con `p = -1`, con `bye` y cuando caduca en el roster.

## 7. Lo de los demás

Al pasar el ratón por la fila de un hermano que comparte, el texto incluye "Descansada: 45% de un nivel". Si además es un compañero de leveo que encaja, salen las dos líneas.

## 8. Pruebas

- Cálculo: 0 sin XP descansada, redondeo, tope 150, oculto a nivel 60.
- Cabecera: el texto aparece y se actualiza con los eventos.
- Aviso: una vez al llegar al tope; apagado con la opción.
- Envíos: nada con la opción apagada (por defecto); al activarla; `-1` al desactivarla; con el latido solo si cambia 5 o más y ha pasado un minuto; a un recién llegado después del latido; nada en instancias; `-1` antes de que se pare el transporte.
- Recepción: desconocidos ignorados; `-1` y `bye` borran el dato; tooltip con el valor.
- Formato: ida y vuelta de `rx`, fuera de rango rechazado.
- Simulación `/lm sim rested`.

## 9. Riesgos

- El tope del 150 % y el nivel máximo 60 se comprueban en el juego.
- El texto junto al título comparte fila con la caja de búsqueda; hay que verlo en el juego.
