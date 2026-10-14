# Rendimiento Fase 08 — mediciones locales

## Matching SQL

La reproducción original sin cambios está en [benchmark-original](evidence/benchmark-original.txt).
Antes de editar se tomaron planes `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` y
30 muestras por modo más dos calentamientos separados. El benchmark usa 6.000
recetas, 18.000 ingredientes de receta y 6.000 pasos, mismo actor SQL B,
`authenticated` y RLS activada; cada ejecución revierte fixtures con rollback.
Los usuarios SQL del benchmark no son sesiones GoTrue. Las suites A/B/C reales
verifican la seguridad por separado.

| Modo | Antes mediana ms | Antes p95 ms | Después 015 mediana ms | Después p95 ms | Reducción mediana |
|---|---:|---:|---:|---:|---:|
| exact | 1793,397 | 1831,877 | 123,6365 | 131,979 | 93,106 % |
| near | 1969,7035 | 2000,719 | 138,940 | 143,092 | 92,946 % |
| next | 1819,411 | 1861,981 | 121,0265 | 125,869 | 93,348 % |

Resultado: PASS para el objetivo local de SQL habitual <500 ms y p95 <1 s.
El percentil se calcula por rango nearest-rank; 30 muestras no son una garantía
estadística de producción. El p95 mejora 92,795/92,848/93,240 % respectivamente.
Los resultados normalizados tienen hash idéntico en las tres etapas y todas las
32 ejecuciones por modo devuelven nueve filas (8+1). La comparación verifica
entorno, filas y hashes, no solo el tiempo:
[comparación](evidence/benchmark-comparison.json).

012 deja intacta la función matching 010: cambia las policies que autorizaban
repetidamente cada línea. Antes, el plan hacía miles de lecturas indexadas para
validar permisos y muchas búsquedas de alias por fila. Las relaciones pasan a
un semijoin sobre IDs de recetas visibles por RLS y el conjunto simétrico de
bloqueos se calcula por sentencia. No hay cache privilegiada de recetas, RLS
deshabilitada, selección persistente ni aproximación del algoritmo.

| Plan interno | Hits compartidos antes | Tras 012 | Tras 015 | Máximo de memoria de nodo reportado |
|---|---:|---:|---:|---:|
| exact | 175415 | 18736 | 41334 | 3625 KiB antes/después |
| near | 194537 | 26650 | 55573 | 3625 KiB antes/después |
| next | 175311 | 18632 | 41147 | 3625 KiB antes/después |

Se informa el contador del nodo raíz, sin sumar hijos y duplicar buffers. Las
lecturas compartidas de disco del plan medido son cero: cache caliente local.
El valor de memoria es el máximo de los nodos que EXPLAIN lo informa, no la RAM
total del servidor ni del cliente. No se midió memoria completa del proceso
PostgreSQL por consulta. Los planes conservan nombres de índices y loops; entre
los índices usados están las PK de recetas/perfiles/ingredientes, alias y el
orden de ingredientes de receta. La mejora no exige que desaparezcan los seq
scans razonables sobre el conjunto de candidatos.

La etapa 012 sola dio medianas 40,482/43,2405/41,1915 ms. El resultado final más
alto incluye el coste de cuenta activa y restricciones de moderación de 014/015;
se publica ese valor final para evitar atribuir al producto solo la etapa rápida.
Gracia, locks de subida y corrección del regex de avatar no modifican la consulta
de matching. Migraciones históricas y script original conservados.

Planes, SQL y muestras:
[antes](evidence/benchmark-before/summary.json),
[012](evidence/benchmark-after-012/summary.json),
[015](evidence/benchmark-after-015/summary.json).
[Criterio oficial RLS](https://supabase.com/docs/guides/troubleshooting/rls-performance-and-best-practices-Z5Jjwv).

## HTTP, parseo y procesamiento de imagen

Fuente: [general-performance.json](evidence/general-performance.json) y
[ejecución](evidence/e2e-performance-final.txt). Veinte muestras y un calentamiento
excluido por operación, host Windows `flutter test` debug/JIT, repositorios reales,
HTTP loopback y parseo DTO. Un feed con una receta pública, recetario con una
receta, catálogo 50/74 y snapshot de compra con 200 productos. No es la fixture
SQL de 6.000 recetas ni una medición de UI Android.

| Operación | Mediana ms | p95 ms | Alcance |
|---|---:|---:|---|
| Entrada Comunidad | 3,633 | 5,916 | HTTP+DTO, feed no vacío |
| Mis recetas | 3,060 | 3,562 | HTTP+DTO |
| Detalle | 4,415 | 5,025 | Cabecera y relaciones autorizadas |
| Catálogo | 3,430 | 3,995 | 50 ingredientes y alias |
| Resolver alias | 5,1195 | 6,039 | Dos requests por resolución |
| Matching | 7,060 | 8,523 | Datos pequeños de usuario, no benchmark6K |
| Abrir compra 200 | 23,7755 | 25,129 | HTTP+parseo de 200 líneas |
| Añadir producto | 3,730 | 4,329 | RPC idempotente |
| Marcar comprado | 30,6685 | 32,442 | Incluye snapshot fresco + escritura |
| Importar | 5,4735 | 7,276 | Revalidación y transacción checked |
| Imagen1024×768 | 55,0305 | 58,076 | Isolate de CPU, sin subida de red |

Los contadores de requests y bytes de respuesta por operación están en JSON;
excluyen WebSockets, cabeceras, TLS y bytes enviados. No equivalen a consumo móvil
total. La imagen se procesa fuera del hilo de UI, se redimensiona a 1024, quita
metadata y limita a 2 MiB. Subida/descarga reales se verifican en los E2E, sin
atribuirles los tiempos de CPU de esta tabla.

La primera medición general contenía un feed vacío después de borrar A y
privatizar B. Se conserva como [diagnóstico](evidence/general-performance-empty-feed.json)
y se repitió con una publicación y aserción de feed no vacío; la tabla usa esa
repetición. No se presenta la respuesta vacía como rendimiento de renderizado.

## Realtime y renderizado

La regresión de compra repite sockets A/B reales: add/toggle/edit/delete de
producto, desconexión y nueva lectura tras reconexión, C/anon sin eventos y
revocación/bloqueo. El E2E final observa borrado completo con el controller real
y provider de UID controlado: tras estabilizar eventos, 14.349 ms hasta ocultar
la lista, exactamente un canal y cinco lecturas desde crear el controller.
El probe está limitado a la pantalla visible, cada 15 s. No se añadieron canales
por item ni sondeos rápidos. Un evento autorizado puede adelantar esa lectura.

El servidor deniega desde que se confirma la revocación/borrado; la UI puede
conservar una copia hasta el siguiente refresh/probe. Nada recupera copias
exportadas por el usuario. Reordenar/duplicar señales y cambio rápido UID/ruta se
verifican con transportes o repositorios controlados y epochs, sin atribuir al
servidor una emisión artificial fuera de orden. Infraestructura remota NOT_VERIFIED.

Las listas se construyen de forma diferida y paginadas cuando corresponde; los
tests Android ejercitan scroll y los widgets320/200 no desbordan. FPS bajo carga,
perfil de scroll200 en dispositivo físico y red móvil: NOT_RUN. No hay una promesa
de 60/120 FPS basada en SQL o HTTP. La recomendación oficial es usar profile y
hardware real para evaluar el comportamiento final:
[Flutter performance](https://docs.flutter.dev/perf/ui-performance).

Profile compiló, instaló y arrancó el APK estándar en Pixel_10a/Android17.
Veinte reinicios de proceso, un warmup excluido y cache del SO caliente dieron
Activity TotalTime mediana 1364,5 ms/p95 1414ms. Una muestra PSS119641KiB
(116,84 MiB), app sin configuración de backend. Es tiempo de la actividad y RAM
en ese estado: no latencia hasta datos cargados, crecimiento de memoria durante
sesión larga ni análisis de frames. [Muestras](evidence/android-profile-metrics.json),
[memoria](evidence/android-profile-memory.txt), [ejecución](evidence/android-profile-attempt.txt).
DevTools sobre scroll200, red móvil y hardware físico: NOT_RUN.
