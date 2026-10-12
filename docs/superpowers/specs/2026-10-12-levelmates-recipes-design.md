# LevelMates: recetas compartidas y "¿quién fabrica esto?" (proyecto 4)

Pedido en chat el 2026-10-12 ("ok"), dentro de la hoja de ruta de [sincronización v2](2026-10-12-levelmates-sync-v2-design.md). Las ideas vienen de las [notas de funciones](../../research/2026-10-12-guild-features-notes.md); no se copia código ni datos de otros addons.

Sale en la **0.4.0**, con los proyectos 1 a 3.

## Por qué

La pestaña Oficios dice quién tiene qué profesión y a qué nivel, pero no **qué sabe fabricar**. Para pedir una poción o una bolsa hay que preguntar en el chat.

## 1. Leer mis recetas

- **Cuándo:** solo mientras está abierta **mi propia** ventana de profesión. Sin ventana, el juego devuelve una lista vacía que parece "no sé nada".
- **Eventos:** `TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE` y `TRADE_SKILL_DATA_SOURCE_CHANGED`. Cada uno reinicia una espera de **1,5 s** y se lee una sola vez cuando hay calma, porque la primera lista tras cambiar de profesión todavía es la anterior.
- **Qué se lee:**
  - `C_TradeSkillUI.IsTradeSkillReady()`;
  - la línea de la profesión con su nivel y máximo (`GetTradeSkillLine` o `GetBaseProfessionInfo`);
  - `GetAllRecipeIDs()`, y de cada receta aprendida (`GetRecipeInfo(id).learned ~= false`) el **objeto que produce** (`GetRecipeOutputItemData` o, si no, `GetRecipeItemLink`).
  - Las recetas sin objeto (encantamientos) se guardan aparte como hechizos.
- **Nunca de otro:** se ignora la ventana si `IsTradeSkillLinked()`, `IsTradeSkillGuild()`, `IsTradeSkillGuildMember()` o `IsNPCCrafting()` dicen que no es la mía. Además, la profesión tiene que estar en mi `GetProfessions()` con el mismo nivel.
- **"Desconocido" no es "vacío":** una lectura vacía nunca borra una llena.

## 2. Guardar y compartir

- **Formato:** por profesión, ids de objeto ordenados, sin repetir, como **diferencias en base 36** separadas por `-`; los hechizos, igual, en un segundo campo. Unas 200 recetas son unos 500 caracteres.
- **Nuevo estado personal `rc`**, uno por profesión (el mecanismo común de datos personales):
  - campos `p` (línea de profesión), `r` (nivel), `m` (máximo), `i` (objetos) y `s` (hechizos);
  - va **en trozos** cuando no cabe en un mensaje;
  - se envía **8 s** después de un cambio real (recetas o nivel) y a quien entra.
- **Interruptor** existente "Compartir profesiones": si está apagado, no se envía nada.
- **Al recibir:**
  - decodificar con límites: diferencias mayores que 0, como mucho 800 por profesión, ids razonables. Si no pasa, se ignora entero.
  - **plausibilidad:** un nivel por encima de 75, 150 y 225 exige personaje de nivel 10, 20 y 35 respectivamente (según su latido); si no, se ignora.
- **Se guarda por hermandad.** Lo de cada compañero se olvida a los **60 días** sin noticias.

## 3. "¿Quién fabrica esto?"

**En la pestaña Oficios**, un buscador que acepta **un enlace de objeto**, **un número de objeto** o **un nombre**. Los nombres se buscan entre los objetos que el cliente conoce: `GetItemInfo` sobre los ids de las recetas guardadas, que se van resolviendo poco a poco.

**Resultado:** una fila por quien lo fabrica, con:
- nombre, profesión y nivel con su barra;
- conectado o "visto hace…";
- "aprendido hace…" (cuándo se leyeron sus recetas).

**Al pulsar una fila:**
- **Pedir**: susurra "¿Me podrías hacer [objeto]?" con el enlace. Como mucho una vez por persona y objeto cada 60 s, y solo con el clic.
- Invitar.

**Navegar sin buscar:** con el buscador vacío, la pestaña muestra lo de siempre (profesiones y quién las tiene). Pulsar a alguien abre **sus recetas**, agrupadas por tipo de objeto, con la lista larga en páginas.

## 4. En la descripción del objeto

Al pasar el ratón por cualquier objeto, si alguien de la hermandad lo fabrica:
- **una línea "Lo fabrica: Mario (Alquimia 225), Ana…"**, con hasta 3 nombres y "+N" para el resto;
- los conectados primero.

Usa `TooltipDataProcessor.AddTooltipPostCall`, como ya hacen deseos y mercadillo. Si el gancho da un error, se apaga solo y avisa una vez.

## 5. Aviso de entrenar

En Oficios, una profesión con el nivel **igual a su máximo** (por debajo de 300) muestra "entrena (siguiente rango)": Oficial a 75, Experto a 150, Artesano a 225. Va en mi fila y en las de los demás.

## 6. Mensajes

| Tipo | Clase | Campos | Notas |
|---|---|---|---|
| `rc` | personal (a trozos si hace falta) | `p` (int), `r`, `m` (int 0-450), `i` (base 36), `s` (base 36) | uno por profesión del jugador; `S.Personal` con varios mensajes |

## 7. Pruebas

- **Lectura:**
  - con la ventana simulada, una profesión con 3 recetas y un encantamiento da los objetos y el hechizo correctos;
  - una ventana enlazada o de la hermandad se ignora;
  - una lectura vacía no borra;
  - la espera de 1,5 s junta varios eventos en una sola lectura.
- **Codificación:**
  - ida y vuelta de 200 ids;
  - ids repetidos y desordenados;
  - rechazo de basura, de diferencias de 0 y de más de 800.
- **Compartir:**
  - el mensaje va en trozos y llega entero;
  - plausibilidad (nivel 225 en un personaje de nivel 12 se ignora);
  - olvidado a los 60 días.
- **Buscar:**
  - por enlace, por número y por nombre;
  - las filas;
  - "Pedir" susurra una vez cada 60 s y solo con el clic.
- **Descripción:** la línea con 3 nombres y "+N"; los conectados primero.
- **Entrenar:** 75/75 dice "Oficial"; 300/300 no dice nada.
- **Con varios jugadores:** Ana abre su ventana de Alquimia y se va; Cris entra y encuentra quién hace "Poción de sanación menor".

## Fuera de este proyecto

- **"Abrir la profesión de otro"** con su enlace: depende de que esté conectado y de funciones protegidas. Queda para más adelante.
- **Precios de reactivos:** ya están en el mercadillo.
