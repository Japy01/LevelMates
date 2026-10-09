# LevelMates: compañero de leveo

Pieza 2 de 4 para la primera versión pública (la 1, buscar grupo de mazmorra, ya está hecha; quedan metas/diario/XP descansada y Discord). Se apoya en el roster, el tablón, los mensajes por hermandad y la política de Blizzard de la spec de v1.

## 1. Objetivo

Que dos hermanos de nivel parecido que quieren subir acompañados se encuentren sin preguntar en el chat de hermandad. Éxito: marco "Busco compañero", otro hermano a 3 niveles o menos también lo tiene marcado, y los dos nos vemos destacados en el tablón y con un aviso en el chat.

## 2. Alcance

**Dentro:** casilla "Busco compañero" por personaje; emparejado por nivel (±3, cualquier zona); destacado y orden en la pestaña Hermanos; aviso en el chat una vez por persona; apagado automático al agruparse con otro que buscaba; ajuste para apagar los avisos; simulación con `/lm sim pal`.

**Fuera, a propósito:** pestaña propia; ver el progreso del otro; avisos de conexión; parejas fijas; emparejar por misiones (ya lo hace el emparejado de misiones).

## 3. Política (heredada de v1)

- Marcar y desmarcar la casilla es siempre un clic del jugador. Nada se marca solo; el apagado automático solo **apaga**.
- Requiere "Aparecer en el tablón". Con eso apagado no se envía nada y no se ve a nadie.
- Dentro de una instancia no se envía nada (solo `help` y `helpok`, como hasta ahora).
- Solo mensajes de addon a la hermandad. Invitar y susurrar siguen saliendo del clic derecho sobre la fila.

## 4. Mensaje

Un tipo nuevo, `pal`, con un solo campo `p` (entero 0 o 1, obligatorio): 1 = busco compañero, 0 = ya no.

**No se añade al latido (`hb`).** Las versiones anteriores validan el latido campo a campo y descartan entero un latido con un campo desconocido: añadirlo haría que los usuarios con la versión anterior dejaran de vernos en el tablón. Un tipo nuevo lo ignoran sin más.

Cuándo se envía:
- Al marcar o desmarcar la casilla (clic).
- Al entrar al mundo, al recargar y cuando el transporte vuelve a arrancar, si la casilla está marcada, justo después del anuncio del roster.
- A quien acaba de conectarse, si la casilla está marcada: después de mi latido, en el mismo momento que el anuncio de mazmorra (evento del roster tras responder a un `ping`), para que el recién llegado ya me conozca.
- `p = 0` al apagar "Aparecer en el tablón", con envío inmediato antes de que el transporte se pare.

Un `pal` de un nombre que el roster no conoce se ignora. Quien sale del juego (`bye`) o caduca en el roster deja de contar, porque la marca vive en su entrada del roster.

## 5. Emparejado

- Un hermano **encaja** conmigo si los dos tenemos la marca y la diferencia de nivel es 3 o menos.
- Se recalcula cuando cambia el roster (niveles, zonas, entradas y salidas) y cuando cambio mi casilla.
- Aviso en el chat: "Ana (21) también busca compañero, en Los Baldíos." Una sola vez por persona y sesión, en el momento en que pasa a encajar. Sin sonido. Ajuste "Avisos de compañero de leveo" (activado por defecto).

## 6. Interfaz (pestaña Hermanos)

- Casilla **"Busco compañero"** en la cabecera, bajo la caja de búsqueda. Solo en la pestaña Hermanos.
- Quien encaja conmigo sale **arriba del todo**, los de mi zona primero; el resto de la lista sigue el orden elegido.
- Su fila lleva un fondo verde suave y, al pasar el ratón, el texto "Busca compañero".
- Quien tiene la marca pero no encaja (más de 3 niveles) no se destaca: así el tablón no se llena de marcas inútiles.

## 7. Apagado automático

Al cambiar el grupo, si tengo la marca y en mi grupo hay alguien que también la tenía, se apaga la mía, se envía `p = 0` y sale "Has encontrado compañero: Ana." Al recargar o volver a entrar sigue apagada.

## 8. Pruebas

- Formato: ida y vuelta de `pal`, `p` fuera de 0-1 rechazado, sin `p` rechazado.
- Emparejado: ±3 incluido, 4 no; los dos deben tener la marca; desconocidos ignorados; la marca se pierde con `bye`.
- Tablón: orden (encajan primero, los de mi zona antes), fondo destacado, tooltip, casilla solo en Hermanos, filtro de nivel y búsqueda siguen funcionando.
- Aviso una sola vez por persona; ajuste apagado sin aviso.
- Envíos: al marcar, al entrar, a un recién llegado después del latido, `p = 0` al apagar compartir; nada en instancias; nada sin compartir.
- Apagado automático al agruparse con alguien marcado; no con alguien sin marca.
- Persistencia por personaje entre recargas.
- Simulación `/lm sim pal`.
- En el juego, con otra persona: verse, aviso, apagado al agruparse.

## 9. Riesgos

- El diseño de la cabecera con la casilla nueva hay que verlo en el juego.
- Quien apaga "Aparecer en el tablón" sigue en el tablón de los demás hasta que caduca (problema anterior de v1, fuera de esta pieza); su marca sí se quita al momento con `p = 0`.
