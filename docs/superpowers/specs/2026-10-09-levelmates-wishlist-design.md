# LevelMates: lista de deseos

Pieza separada que pidió el usuario después del diario y las metas. Se apoya en el roster, el bus de eventos, la pestaña del tablón, el registro de botín del diario y la política de v1 (nada fuera del juego, mensajes nuevos con su propio tipo).

## 1. Objetivo

Que cada uno apunte los objetos que quiere conseguir y que la hermandad lo sepa, para pasárselos cuando les caigan. Éxito: Ana apunta [Espada de X]; a Mario le cae esa espada en una mazmorra y le sale "Ana quiere [Espada de X]"; al pasar el ratón por el objeto, cualquiera ve "Lo quiere: Ana".

## 2. Mi lista

- Hasta **10 objetos por personaje** (`ns.char.wishes`, lista de `{ id, t }`, en el orden en que se añadieron).
- **Añadir**: botón "Añadir deseo" en la pestaña Deseos → cuadro pequeño "Mayús+clic en un objeto". Mientras el cuadro está abierto, un Mayús+clic en cualquier objeto (bolsas, chat, botín, diario de mazmorras) pone su enlace en el cuadro; "Añadir" lo guarda. Un objeto repetido, un enlace que no es de objeto o la lista llena se rechazan con una línea en el chat.
- **Quitar**: clic derecho en mi fila → "Quitar de la lista".
- **Conseguido**: si me cae un objeto de mi lista (mi propio botín, el mismo análisis del diario: mi GUID o mi nombre), aviso "¡Conseguiste [objeto] de tu lista!" y se quita solo.

## 3. La hermandad

- Mensaje nuevo **`wl`** con mi lista entera: `ids` = números de objeto separados por comas (0 a 10). Lista vacía = `ids` ausente (la retiro). Las versiones anteriores lo ignoran.
- Se envía al añadir o quitar, y a quien acaba de conectarse (después de mi latido), si tengo algo o si tengo una retirada pendiente.
- Si el envío se rechaza (dentro de una instancia, "Aparecer en el tablón" apagado), queda pendiente en los datos del personaje y sale después del siguiente latido (así sobrevive a /reload y a cerrar sesión).
- Solo se aceptan listas de hermanos que el roster conoce. Más de 10 números, o números fuera de rango, invalidan el mensaje.
- Las listas de los demás se guardan por cuenta y por hermandad: `ns.db.wishes[hermandad][nombre] = { ids, t }`. Se olvidan si no se actualizan en **30 días**, y no se muestran si esa persona ya no está en la hermandad.

## 4. Avisos

- **Objeto que quiere un hermano**: si me cae (mi botín) un objeto de la lista de otro, "Mario quiere [objeto]. ¡Pásaselo!". Una vez por objeto y persona cada sesión. Opción en los ajustes para apagarlo ("Avisos de deseos"), encendida por defecto.
- **Tooltip**: al pasar el ratón por cualquier objeto, si alguien lo quiere, una línea "Lo quiere: Mario, Ana" (mi nombre incluido si es mío). Usa `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, …)`; si el cliente no lo tiene, no hay línea (sin error).

## 5. Interfaz

- **Pestañas clásicas**: las pestañas del tablón (Hermanos, Mazmorras, Diario, Metas, Deseos) pasan a ser pestañas de WoW colgando bajo la ventana (`PanelTabButtonTemplate`, como el diario de mazmorras). La barra de abajo queda para los botones de cada pestaña; esto arregla el solape actual entre la última pestaña y la casilla "Cerca de mi nivel".
- **Pestaña Deseos**: columnas quién, objeto (enlace con su color de calidad; tooltip del objeto al pasar el ratón) y desde cuándo. Primero los míos, luego los de los demás por nombre. Los objetos que el cliente aún no tiene cargados se piden (`Item:CreateFromItemID(id):ContinueOnItemLoad`) y la fila se refresca cuando llegan; mientras tanto, "Objeto #id".
- `/lm deseos` (y `/lm wishlist`) abre la pestaña.

## 6. Simulación

`/lm sim deseos`: Mario y Ana con dos deseos cada uno (solo en local, nada se envía); `/lm sim off` los quita.

## 7. Pruebas

- Formato de `wl` (lista, vacío, más de 10, números fuera de rango).
- Añadir: enlace válido, repetido, no objeto, lista llena; quitar; conseguido al caer.
- Difusión: al cambiar, a un recién llegado, pendiente tras rechazo y tras /reload; solo del roster; olvido a 30 días y de quien deja la hermandad.
- Aviso de objeto que quiere un hermano (una vez); opción apagada.
- Línea del tooltip.
- Pestañas clásicas (las cinco, la seleccionada recordada, botones por pestaña) y la pestaña Deseos con el cuadro de añadir y el Mayús+clic.
- Simulación.

## 8. Riesgos

- El gancho de Mayús+clic (`ChatFrameUtil.InsertLink`) y el del tooltip se comprueban en el juego; si el cliente de Forever los nombra distinto, se cae al cuadro de texto donde se puede pegar el enlace a mano.
- El aviso "Mario quiere…" solo funciona con el botín propio; no se ve lo que cae a otros.
