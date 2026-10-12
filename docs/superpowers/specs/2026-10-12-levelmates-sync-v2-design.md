# LevelMates: sincronización v2 (proyecto 1 de la hoja de ruta "todo lo de Guild Armory")

Aprobado en chat el 2026-10-12: alcance B (todo menos banda y botín; banco sí; banda y botín al final), corte limpio con la 0.3.x ("B") y la capa de sincronización común ("haz lo que tú recomiendes pero bien").

Fuentes: [prácticas de sincronización](../../research/2026-10-12-guild-sync-practices.md) y [notas de funciones](../../research/2026-10-12-guild-features-notes.md). Las dos son notas en prosa sobre otro addon. **No se copia su código.** Todo lo de aquí se escribe desde cero.

## Hoja de ruta (una versión por proyecto)

1. **Sincronización v2.** Este documento. Versión 0.4.0.
2. **Grupos y Discord:**
   - partidas con 5 plazas por rol y el líder con autoridad;
   - rol preferido;
   - grupos sugeridos ("Juntos") e "Invitar a todos";
   - anunciar en Discord (`GUILD_DISCORD`).
3. **Misiones y mapa:**
   - tablón de misiones con Alt+clic;
   - misiones de grupo compartidas;
   - marcadores agrupados y a tamaño fijo;
   - hogueras.
4. **Oficios:**
   - recetas compartidas (diferencias en base 36);
   - "¿quién fabrica esto?";
   - descripción del objeto;
   - aviso de entrenar.
5. **Hermandad:**
   - notas compartidas y mensaje del día propio;
   - historial de entradas, salidas y rangos;
   - alts con fuerza del enlace;
   - carrera al 60;
   - banco de la hermandad.
6. **Armería:** equipo propio y compartido, nivel de objeto bien calculado, muñeco con modelo y talentos de todas las clases.
7. **Interfaz:**
   - barra de mensajes ("hecho / no se pudo");
   - "¿Seguro?";
   - notificaciones bajo el minimapa con contador;
   - opciones con buscador;
   - pestañas ocultables;
   - barra de nivel y banner al subir;
   - recolección.
8. **Nivel máximo:** banda (plan, inscripciones, recordatorios) y botín (consejo, tiradas, DKP).

Cada proyecto tiene su propio diseño, plan y versión. Los proyectos 2 a 8 se montan sobre lo que deja este.

## Por qué

- **Los datos de quien no está se pierden para el que entra.** Hoy cada uno solo reenvía lo suyo cuando alguien entra. Si quien creó una quedada, una meta o una oferta del mercadillo no está conectado, quien entra después no la ve, aunque los demás la tengan guardada.
- **No hay lápidas.** Algo borrado puede volver si un cliente con datos viejos lo manda.
- **No hay versiones.** Si llegan dos copias, gana la última que llega, no la más nueva.
- **Lo que haces dentro de una instancia se pierde**, en vez de salir al terminar.
- **El mismo patrón está copiado en 8 módulos:** "pendiente, reenviar al latido, mensaje perdido".
- **Rendimiento:** cada latido de cualquier compañero redibuja el libro entero, unas 30 veces por minuto con 30 personas. Además, cada muerte de un enemigo redibuja el libro y la ventana de XP.

## 1. Protocolo v2 (corte limpio)

**Prefijo nuevo `LVLM2`.** Los clientes 0.3.x no reciben nada nuestro y nosotros no procesamos lo suyo. Así se evitan errores de formato y datos mezclados.

**Aviso a los de la versión vieja:**
- Seguimos escuchando el prefijo `LVLM` solo para detectar a esos clientes.
- Si oímos a un cliente 0.3.x, le mandamos con el prefijo viejo **un latido mínimo con nuestra versión**, como mucho una vez cada 5 minutos. Su 0.3.x ya muestra "hay una versión nueva" cuando ve un número mayor.
- En la ficha y en el informe salimos como "usa una versión antigua".

**Formato:** el mismo que ahora (`2<US>tipo<US>k=v;…`, escapando `%`, `;`, `=` y los caracteres de control), con el esquema validado por tipo.
- Nunca enlaces, solo números.
- Más de 240 bytes se **rechaza** (error en el informe), nunca se corta.

**Trozos (nuevo `Blob.lua`):**
- Las cargas grandes se parten en trozos de unos 150 caracteres. Cada trozo lleva el id del paquete, su posición y el total.
- Se recomponen en cualquier orden y se ignoran los duplicados.
- Un paquete incompleto se descarta a los 30 s. Si se repite el id con otro total, se reinicia.
- No hay confirmaciones de recepción: la siguiente ocasión lo vuelve a mandar.
- Si cabe en un solo mensaje, va en uno.

**El canal oculto de reserva** (modo auto) se mantiene igual, con el nombre nuevo derivado de la versión.

## 2. Cola de envío

La cola actual (ráfaga de 10 y luego 1 por segundo, tic cada 0,2 s) pasa a:

- **Dos vías:**
  - **urgente:** ayuda, avisos de grupo, unirse o salir;
  - **normal:** todo lo demás.

  La urgente sale siempre primero.
- **Tope de 300 mensajes.** Al pasarse se tira el normal más antiguo, luego el urgente más antiguo. Se cuentan los descartes, que salen en `/lm debug` y en el informe.
- **"Solo vale el último"** se mantiene para los tipos que llevan el estado completo y se extiende a los registros (mismo tipo y mismo id).
- **Restricciones** (en Forever las banderas de restricción dan "verdadero" incluso fuera de combate; lo vimos en el experimento):
  - Nos guiamos por **dónde estás** (dentro de una instancia de grupo o banda) y por **el resultado del envío** (código 11, bloqueado). Las banderas no sirven.
  - Dentro de una instancia, los mensajes no urgentes **se guardan** en lugar de tirarse. Caducan a los 60 min; los urgentes, a los 10.
  - Al recibir el código 11 se guarda el mensaje y se reintenta.
  - Se reanuda 2 s después de cambiar de zona, salir de combate o entrar al mundo.
- **El tic solo funciona con la cola llena.** Con la cola vacía se para; hoy gira siempre.

## 3. Almacén de registros (nuevo `Sync.lua`)

Cada dato compartido es un **registro**:

```
{ tipo, id, dueño, rev, caduca, borrado, datos }
```

- `rev` es la hora del servidor (`GetServerTime`) cuando el dueño lo cambió. Si coincide, se desempata por id.
- `caduca` es la hora en que deja de valer. Cada tipo define su vida máxima.
- `borrado = true` es una **lápida**: no lleva datos y caduca cuando habría caducado el registro.

**Dos clases de tipo:**
- **Personal** (oficios, deseos, logros, puntos, alts, build, macros, meta personal, descansado, compañero):
  - solo lo publica el dueño y se guarda con el nombre que pone el servidor;
  - **no se reenvía**;
  - lo recibido se guarda como ahora en las variables guardadas, para verlo cuando el dueño no está;
  - un mensaje de otro con ese tipo se rechaza.
- **Tablón** (quedadas y apuntados, anuncios de grupo y apuntados, metas de hermandad y aportaciones, mercadillo y reservas, muro, preguntas de clase, plantillas de reclutamiento):
  - todos guardan los registros de todos y **se reenvían** a quien entra;
  - el reenvío lleva el dueño original;
  - un reenvío solo se acepta si:
    - no hay lápida;
    - no es nuestro;
    - es más nuevo que el que tenemos;
    - no viene del futuro (más de 5 min);
    - no ha caducado.

**Quién puede cambiar o borrar un registro de tablón:**
- solo el **dueño**;
- en tipos con autoridad, también quien ella diga. Hoy son los oficiales en las metas y las plantillas de reclutamiento. El proyecto 2 añade al líder de la partida.

**API para los módulos** (sustituye el patrón copiado):

```
Sync.Define(tipo, { clase = "personal"|"tablon", vida = segundos, esquema = {...},
                    alCambiar = fn(registro, anterior), max = n })
Sync.Put(tipo, id, datos)      -- mío: rev = ahora, lo guarda y lo envía
Sync.Remove(tipo, id)          -- mío: lápida, la guarda y la envía
Sync.Get(tipo, id) / Sync.List(tipo [, filtro])   -- solo vivos
```

- `Put` y `Remove` funcionan sin conexión: si el envío falla o se retiene, se queda **pendiente** y sale al siguiente latido. Esto sustituye las ocho copias del patrón.
- **Las listas no borran mientras se leen.** La limpieza de caducados va en un temporizador común cada 60 s y avisa de lo que quitó.

## 4. Puesta al día

**Al entrar** (hoy es un "ping"):
1. Mandas `hola` con tu versión y un **resumen por tipo de tablón**: número de registros vivos más lápidas, y una suma de control de sus `rev`.
2. Cada uno que tenga **algo distinto** en un tipo espera un tiempo al azar de 1 a 6 s.
   - Si en ese tiempo oye que otro ya te ha contestado ese tipo, se calla.
   - Si no, te manda **por susurro** sus registros de ese tipo, de lo más antiguo a lo más nuevo, como mucho 20 por tanda, y las lápidas.
3. Si tras la tanda tu resumen sigue siendo distinto, pides otra (`quiero`) a **uno solo**, con una petición pendiente cada vez.
4. Los **personales** los manda cada dueño al oír tu `hola`, tras un tiempo al azar de 0 a 5 s, como ahora.

**Escalonado al entrar:**
- el latido, inmediato;
- el `hola`, a los 3 s;
- los personales propios, a los 8 s;
- los avisos se silencian los primeros 20 s, para que la puesta al día no dispare avisos viejos.

**Límites:**
- el muro se reenvía solo de las últimas 48 h, como mucho 40 entradas;
- el mercadillo y los deseos, lo vivo;
- las preguntas de clase, 24 h.

## 5. Identidad y nombres

- **Solo nos fiamos del nombre que pone el servidor.** `ns.Me()` ya da el nombre completo con apellido; es el arreglo de hoy.
- **Nombres:** se separan del reino solo por el guion. Los susurros van sin reino. Las invitaciones, con la grafía de la lista de la hermandad.
- **Por canal:**
  - en `GUILD` se acepta todo, porque el servidor solo entrega a miembros;
  - por susurro o canal oculto, solo miembros de la lista.

  Si la lista no está cargada, se rechaza y se pide recargarla.
- **"Desconocido" nunca es "vacío":** una lista vacía no borra una llena, y una lista de la hermandad incompleta no quita a nadie.

## 6. Qué pasa con cada función actual

| Función | Tipo | Clase | Notas |
|---|---|---|---|
| Quedadas (`qd`) y apuntados (`qj`) | `quedada`, `apuntado` | tablón | El apuntado es un registro del que se apunta, con id `quedada:nombre`. |
| Anuncios de grupo (`lfg`) y apuntados (`lfj`) | `grupo`, `grupoap` | tablón | Vida: los minutos del anuncio. |
| Metas de hermandad (`go`, `gd`, `gc`) | `meta`, `metaap` | tablón | Autoridad: oficiales. |
| Mercadillo (`gv`, `sl`, `gr`, `gro`) | `oferta`, `reserva` | tablón | |
| Muro (`fe`) | `muro` | tablón | 7 días; reenvío limitado (ver sección 4). |
| Preguntas de clase (`ask`) | `pregunta` | tablón | 24 h. |
| Plantillas de reclutamiento (`rt`, `rc`) | `reclutar` | tablón | Autoridad: oficiales. |
| Deseos, oficios, build, macros, alts, puntos, logros, meta personal, descansado, compañero | uno por función | personal | Mismo contenido; pasan por `Sync.Put`. |
| Latido (`hb`), XP en grupo (`xp`), progreso de misión (`qo`), misiones (`q`), raros (`rr`), ayuda (`help…`), adiós | — | sin almacén | Momentáneos. Siguen siendo mensajes sueltos, con la vía urgente para la ayuda y los grupos. |

**Migración de lo guardado:** al cargar la 0.4.0, lo que hay en las variables guardadas de cada módulo se convierte a registros. Si algo no se entiende, se descarta sin error. Una sola vez, con una marca de versión de datos.

## 7. Rendimiento

- **Redibujado agrupado:**
  - `ns.Dirty()` marca la vista abierta;
  - un único temporizador la redibuja **como mucho cada 0,5 s** y solo si está visible;
  - así lo hacen el libro, la ficha, el panel de mazmorra y la ventana de XP.
- **Solo hay eventos si cambió algo:**
  - `LM_ROSTER_CHANGED` solo si cambian el nivel, la zona, el grupo o la clase de alguien;
  - el descansado y la XP, como mucho cada 2 s;
  - la caducidad de la ayuda solo avisa si caducó algo.
- **Nada de temporizadores encadenados ni funciones creadas en caliente:**
  - un único marco de temporizadores con acumulador para la cola, la limpieza y los redibujados;
  - las funciones auxiliares, fuera de las funciones que se llaman a menudo.
- **El muro y el diario:**
  - añadir es inmediato (índice por clave);
  - el diario recorta en bloque, no de uno en uno.
- **Medir:** `/lm debug` muestra la memoria antes y después de una recolección, los mensajes por tipo y los descartes de la cola.

## 8. Errores y avisos

- Un registro que no pasa el esquema se ignora y se cuenta (aparece en el informe). Nunca salta un error al jugador.
- Lo pendiente que caduca sin salir se cuenta en el informe.
- Si alguien usa la 0.3.x, sale en su ficha como "usa una versión antigua".

## 9. Pruebas

Ya tenemos `tools/wow-stub.lua`. Se añade un modo **"varios clientes"** en las pruebas: el mensaje de uno se entrega a los demás con su nombre de servidor. Hay que probar:

- **Reenvío:**
  - A crea una quedada y se va; C entra; B se la da; C la ve.
  - Con B y D conectados, solo uno contesta.
- **Lápidas:** A borra; B, que tenía la copia vieja, no la resucita al reenviar.
- **Versiones:** dos copias en distinto orden; gana la de `rev` mayor.
- **Personal:** un mensaje de B que dice ser de A se rechaza.
- **Trozos:** desordenados, duplicados, incompletos (se tiran a los 30 s), id repetido con otro total.
- **Cola:**
  - la urgente pasa primero;
  - el tope de 300;
  - dentro de una instancia se guarda y sale al salir;
  - el código 11 se retiene.
- **Protocolo:**
  - un mensaje `LVLM` v1 se ignora;
  - se manda un latido viejo con la versión como mucho cada 5 min.
- **Migración:** las variables guardadas de la 0.3.2 se convierten sin pérdidas.
- **Rendimiento:**
  - 30 latidos en un segundo dan un solo redibujado;
  - un latido sin cambios no dispara `LM_ROSTER_CHANGED`.
- **Lo que ya hay:** las 170 pruebas actuales siguen en verde, adaptadas al prefijo nuevo donde haga falta.

## Fuera de este proyecto

Discord, el líder de la partida, el tablón de misiones, las recetas, la posición por movimiento, el historial y la interfaz nueva van en los proyectos 2 a 7. Este proyecto deja lista la base para todos ellos.
