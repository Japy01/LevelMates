# LevelMates: cuadrícula de mazmorras

Mejora de la pestaña Mazmorras pedida por el usuario: "casi el mismo listado con las imágenes de las mazmorras del otro addon" (ForeverDungeonJournal). Aprobado en chat: cuadrícula de tarjetas y ampliar la lista a 14 mazmorras.

## 1. Mazmorras

Catorce, con sus niveles (los del diario de mazmorras de Forever):

| id | Mazmorra (enUS / esES) | Niveles |
|---|---|---|
| 1 | Hall of Thanes / Salón de los Feudales | 13-20 |
| 2 | Ragefire Chasm / Sima Ígnea | 13-18 |
| 3 | Ruins of Lordaeron / Ruinas de Lordaeron | 15-22 |
| 4 | Wailing Caverns / Cuevas de los Lamentos | 15-24 |
| 5 | The Deadmines / Minas de la Muerte | 17-26 |
| 6 | Shadowfang Keep / Castillo de Colmillo Oscuro | 20-30 |
| 7 | Blackfathom Deeps / Cavernas de Brazanegra | 24-32 |
| 8 | The Stockade / Las Mazmorras | 24-32 |
| 9 | Excavation Site: Wetlands / Excavación: Los Humedales | 26-33 |
| 10 | City of Dalaran / Ciudad de Dalaran | 28-33 |
| 11 | Gnomeregan / Gnomeregan | 29-38 |
| 12 | Razorfen Kraul / Horado Rajacieno | 29-38 |
| 13 | Scarlet Monastery: Graveyard / Monasterio Escarlata: Cementerio | 30-38 |
| 14 | Scarlet Monastery: Library / Monasterio Escarlata: Biblioteca | 33-41 |

Los ids 1-6 no cambian (viajan en `lfg` y en las metas `dun`). El mensaje `lfg` ya admite ids hasta 99.

## 2. Imágenes

- Pantallas de carga del propio juego (`Interface\Glues\LoadingScreens\…` o su número de archivo), recortadas con las mismas coordenadas que usa el diario de mazmorras.
- Salón de los Feudales, Ruinas de Lordaeron y la Biblioteca del Monasterio usan imágenes propias del autor de ForeverDungeonJournal: **no se copian**. Se usan desde su carpeta solo si ese addon está cargado; si no, la Biblioteca usa la pantalla del Cementerio (el mismo monasterio) y las otras dos se muestran sin imagen (tarjeta oscura con el nombre).

## 3. Pestaña Mazmorras

- Una **tarjeta por mazmorra** en cuatro columnas, ordenadas por nivel: imagen arriba, nombre, niveles y "N buscan" si hay anuncios (incluido el mío).
- Las que encajan con mi nivel se resaltan (fondo dorado, imagen a color); las demás quedan atenuadas.
- **Ratón encima**: el nombre, los niveles y cada anuncio (jugador, roles, nota).
- **Clic**: menú con "Susurrar a X" e "Invitar a X" por anuncio de otros, "Retirar mi anuncio" si el mío es de esa mazmorra, y "Buscar grupo aquí" (abre el cuadro de buscar grupo con esa mazmorra elegida).
- El buscador filtra tarjetas por nombre de mazmorra o de jugador que busca en ella.
- El botón de abajo ("Buscar grupo" / "Cancelar mi anuncio") se queda igual. Las filas de lista y las cabeceras de columna no se muestran en esta pestaña.

## 4. Pruebas

Catorce mazmorras con nombre en los dos idiomas; tarjetas ordenadas; contador; resaltado por nivel; imágenes (juego, addon cargado o no, recurso de la Biblioteca); tooltip; menú (susurrar, buscar aquí con la mazmorra elegida, retirar el mío); buscador; botones por pestaña.

## 5. Riesgos

- Las metas "mazmorra juntos" comparan el nombre de la instancia que da el juego con el nuestro: los nombres nuevos se comprueban en el juego.
- Las rutas y números de archivo de las imágenes se comprueban en el juego.
