# Mi recetario — contrato de Fase 04

Implementación exclusiva de `prompts/04_MY_RECIPES.md` y la autorización del
propietario. Se mantienen las cuatro pestañas. «Recetas públicas guardadas» es
una sección informativa para Fase 05; no consulta ni simula guardados. Comunidad,
¿Qué cocino hoy? y Lista de compra conservan sus pantallas anteriores.

## Arquitectura y modelos

`features/recipes/domain/recipe.dart` define receta, borrador, ingrediente
canónico/texto libre, visibilidad, filtros, cursor y página tipados. Las pantallas
usan proveedores/controladores de `presentation/recipe_providers.dart`;
`data/supabase_recipe_repository.dart` concentra Auth/PostgREST/Storage. No hay
SDK Supabase en widgets de producto. El catálogo es de solo lectura y no existe
inventario ni selección persistente de ingredientes disponibles en casa.

`RecipeContent` y `RecipePhoto` son reutilizables por fases posteriores. No
incluyen controles de Comunidad, compra ni un modo cocina avanzado. La navegación
añade únicamente `/recipes/new`, `/recipes/:id`, `/recipes/:id/edit`, todas
protegidas por sesión. Las acciones de autor requieren también autorización real
en el servidor.

## Contratos inspeccionados y conservados

Tablas reales: `recipes`, `recipe_ingredients`, `recipe_steps`, `ingredients`,
`ingredient_aliases`; FK de autor a `profiles`. Columnas/grants/checks se mantienen.
No se modifican las migraciones 001–007. Se reutilizan:

| Operación existente | Contrato utilizado |
|---|---|
| `save_recipe` | JSON completo de cabecera/componentes, ID y versión esperada; devuelve UUID. Ingredientes/pasos se reemplazan en una única transacción |
| `set_recipe_visibility` | UUID, private/public y versión; devuelve la versión de servidor. Publicar es una acción explícita |
| `set_recipe_photo` | UUID, path/null y versión; objeto debe existir y ruta pertenecer al autor/receta |
| `resolve_ingredient` | Nombre/alias → UUID o null, normalización autoritativa del catálogo aprobado |
| DELETE propio histórico | Permiso conservado para compatibilidad; la app usa el nuevo borrado versionado |

Nuevas recetas permanecen privadas incluso si un cliente externo intenta mandar
visibilidad en la cabecera. Editar no publica. Una receta exige entre 1 y 100
ingredientes/pasos. Raciones positivas, hasta 10.000, dos decimales; cantidades
opcionales positivas hasta 1.000.000, tres decimales; tiempos enteros 0–10.080.
Se admite coma decimal. Categoría es texto 1–60 y unidad texto opcional 1–30:
el esquema no tiene tablas ni enums de categorías/unidades que se puedan inventar.

## Listado y edición

Consulta siempre filtra `author_id` por usuario actual y deja a RLS decidir.
Orden: `updated_at DESC, id DESC`. Paginación por cursor de ambos campos, 8
recetas más una de detección; deduplicación al concatenar. Si cambian los filtros
o la cuenta, una respuesta antigua no puede añadir datos a la página nueva.
La búsqueda por título usa ILIKE con `%`, `_` y barra escapados; categoría y
visibilidad son filtros exactos. Las categorías proceden de recetas propias.
Con ediciones concurrentes del orden, refrescar reconstruye el listado; no se
promete una instantánea inmutable durante toda la paginación.

El editor ofrece autocompletado por nombre/alias, cantidades/unidades, opcionales,
edición/eliminación de ingredientes y detección de duplicados por UUID o clave
de texto normalizada. Antes de admitir un nombre libre no reconocido localmente,
consulta la RPC existente de resolución; desconocido sigue como texto libre
validado, sin crear un ingrediente de catálogo. PostgreSQL vuelve a validar y
normalizar. Los pasos se añaden/editan/eliminan y suben/bajan; el servidor asigna
los ordinales 0–99 según el array, y la lectura ordena explícitamente por ordinal.

El usuario completa su perfil antes de crear. Se evita doble envío y se conserva
el formulario frente a errores recuperables. Conflicto de versión bloquea otro
guardado hasta recargar, con confirmación explícita de descarte. La recarga espera
datos nuevos; no reutiliza un valor anterior retenido durante AsyncLoading.
Salir de un borrador requiere confirmación. Cambio de cuenta descarta campos,
pasos, fotos y el diálogo de ingredientes; las imágenes de memoria se desalojan
al liberar sus proveedores/formularios. No hay caché privada persistente creada
por el módulo ni promesa de eliminar copias ya descargadas por terceros.

## Migración incremental 008

`20261013000800_recipe_editor_safety.sql` se justifica por tres huecos de una UI
con reintentos/fotos: creación sin clave idempotente, foto sustituida sin cola y
lectura ajena de archivos temporales bajo una receta ya pública. Además protege
la intención de borrar frente a una edición concurrente.

| Adición | Semántica |
|---|---|
| `private.recipe_creation_requests` | Ledger con RLS, no expuesto; actor/request, hash de payload, referencia y timestamp; FK de actor con cascada |
| `create_recipe_once` | Wrapper invoker/implementación privada, Auth UID, bloqueo por actor/request y transacción existente. Mismo payload devuelve mismo UUID; contenido distinto o receta borrada da PT409 |
| `lookup_recipe_creation` | Solo la solicitud del usuario actual. Permite reconciliar una respuesta de creación desconocida sin generar otra receta |
| `delete_recipe_versioned` | Solo autor, bloqueo de cabecera y versión esperada; usa las cascadas y cola existentes |
| `photo_access` | Mismo contrato de escritura propia. Terceros solo leen la fotografía actualmente referenciada de una receta pública accesible |
| Triggers de fotografías | Subida temporal encola; asignar referencia retira su job; reemplazar/quitar encola anterior; borrar receta conserva el trigger histórico |
| Índice | Autor/actualización/UUID para paginación reciente |

No hay tablas de producto nuevas: siguen 16 públicas, ahora 4 técnicas privadas.
PUBLIC/anon no ejecutan los nuevos entry points; definers con search_path vacío
y actor derivado de Auth. Los RPC anteriores y el permiso DELETE propio siguen
compatibles con las pruebas aceptadas; no se afirma que el DELETE histórico
tenga control de versión. El ledger evita también resucitar una receta borrada
al repetir su request. No contiene credenciales.

## Fotografías y límites de atomicidad

Se usa el picker y procesamiento reales de Fase 03: galería, retorno cancelado,
JPEG/PNG/WebP, entrada/salida hasta 2 MiB y 1024 px, máximo 16 millones de píxeles
al decodificar. Este límite de app es más estricto que los 5 MiB del bucket.
Reencodifica a JPEG/RGB nuevo y elimina EXIF/GPS/ICC/texto/animación de origen.
Previsualización sin metadatos originales; Storage no realiza esa transformación
para clientes externos. Rutas impredecibles `<autor>/<receta>/<uuid>.jpg` y
`cacheControl=0`; bucket `recipe-photos` privado.

1. Guardar cabecera/componentes mediante RPC atómica. La receta ya es completa
   aunque aún no haya foto, que es opcional.
2. Subir un archivo nuevo, sin sobrescribir la imagen válida anterior.
3. Asignar el path con versión esperada. Solo entonces cambia la referencia.
4. La foto anterior/temporal queda en cola. La interfaz distingue datos guardados
   de una fotografía pendiente y conserva el borrador para reintentar.

Storage y PostgreSQL no comparten transacción. Una respuesta perdida se verifica
leyendo la referencia actual; nunca se borra a ciegas un archivo que podría haber
quedado asignado. Solo se considera reconciliado un éxito ambiguo si los campos
y componentes también coinciden. Cancelar subida cancela próximos reintentos y
evita vincular la imagen; espera el intento en curso, limitado por el transporte.
No se promete abortar retroactivamente una escritura ya aceptada.

La app descarga bytes autenticados, revalida referencia y permiso, descarta
respuestas de otra cuenta y recarga detalle/foto al volver al primer plano o
pedir actualización. No emite URLs firmadas ni URLs públicas permanentes.
Una URL firmada emitida por otro cliente puede seguir vigente hasta expirar;
una copia descargada no se revoca. La regresión local prueba expresamente esa
ventana; CDN remoto sigue sin verificar.

**Limpieza física pendiente del lanzamiento.** La migración encola, no elimina
blobs. Un futuro trabajador debe aplicar una gracia a las subidas temporales
(propuesta mínima: 24 h) y coordinar una comprobación de referencia bajo bloqueo
antes del borrado por Storage API. No desplegar un consumidor que elimine cada
job inmediatamente. La limpieza privilegiada de fixtures ejecutada desde el host
no es ese trabajador ni forma parte de Flutter; valida los UUID/email/path/owner
locales de la ejecución y elimina únicamente sus objetos de prueba.

## Pruebas y reproducción

Estados/resultados definitivos en [informe Fase 04](reports/PHASE_04_REPORT.md).
Los mocks de `test/support/fake_recipe_repository.dart` demuestran UI/controladores;
no se usan para RLS. `test_support/recipes_local.dart` utiliza tres cuentas reales
A/B/C en Auth/PostgREST/Storage local, con un caso de fallo inyectado tras recibir
una respuesta real de creación ya comprometida, identificado como híbrido.
Las demás pruebas negativas de permisos son peticiones reales directas.

```powershell
.\scripts\verify_recipes.ps1 -BackendChecks -ResetLocal -IncludeAndroidBuild
```

El reset se limita al proyecto `mixtick-phase02` vacío de cuentas. El runner
comprueba aislamiento, ocho migraciones, SQL/lint/API, cliente recetas, Auth en
ambos modos locales de confirmación y calidad Flutter/IDs/APK. Restaura config
en finally y detiene exclusivamente el stack local. No cambia Supabase remoto.

Para Android, con `Pixel_10a`/emulador iniciado:

```powershell
.\scripts\start_isolated_supabase.ps1 -EvidenceDirectory docs/reports/phase04/evidence
& 'C:\Users\Sergio\develop\flutter\bin\dart.bat' run test_support/generate_recipe_gallery.dart
.\scripts\verify_native_recipes.ps1
.\.tooling\supabase\supabase.exe stop --project-id mixtick-phase02
```

La prueba Android usa UI Flutter y galería nativa. El ayudante observa XML de
UIAutomator y selecciona solo la imagen controlada, confirma Done y hace capturas
reales del emulador; no son renders/goldens. Android 17 requiere esa confirmación
tras selección. Se conservan fallos iniciales y capturas transitorias identificadas.
La figura de entrada es una fixture generada por encoder, no una foto de producción.
Las cuentas, archivos, entrada MediaStore y modo noche de pruebas se limpian/restauran.
iOS, dispositivo físico, backend/correo remoto, CDN, Realtime, trabajador,
eliminación completa de cuenta y moderación operativa siguen siendo pendientes.

Documentación primaria consultada: [Supabase: buckets privados](https://supabase.com/docs/guides/storage/buckets/fundamentals),
[descargas](https://supabase.com/docs/guides/storage/serving/downloads),
[Flutter: integración](https://docs.flutter.dev/testing/integration-tests) y
[límites de UI nativa](https://docs.flutter.dev/testing/overview).
