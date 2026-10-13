# ¿Qué cocino hoy? — contrato de Fase 06

La pantalla utiliza las recetas, ingredientes, autores, fotografías y detalle
aceptados. No hay otra base de recetas, inventario, cantidades de casa, IA,
sustituciones o lista de compra funcional. Las cuatro pestañas se conservan.

## Selector y duración

El catálogo de Mi recetario se obtiene por su repositorio existente; nombre y
alias ofrecen sugerencias al escribir. La coincidencia por subcadena sirve
solo para mostrar opciones de autocompletado: seleccionar o añadir consulta
`resolve_ingredient` con el nombre completo. Un alias aprobado se convierte al
UUID canónico. Un término ambiguo como «aceite» permanece literal, sin elegir
oliva/girasol. El usuario puede escoger explícitamente una sugerencia concreta.

Se permiten nombres libres de 1–80 caracteres y hasta 50 selecciones. Chips,
eliminación individual, limpiar y prevención de duplicados por UUID/clave.
Añadir no cierra el selector. El estado solo vive en el widget de esta pantalla:
se conserva al volver del detalle o de otra pestaña mientras siga montada,
se elimina al cerrar sesión/cambiar identidad o destruir el widget, y no se
escribe en disco ni en PostgreSQL. Es una consulta temporal, no una despensa.

`SessionScope` y comprobaciones de actor después de await impiden que una
resolución tardía incorpore ingredientes de la cuenta anterior. La normalización
visual reutiliza la función española existente; PostgreSQL valida/normaliza
otra vez, resuelve alias y deduplica los conjuntos antes de comparar.

## Migración y RPC

Se añade únicamente `20261013001000_cook_today_matching.sql`; 001–009 intactas.
Sin nuevas tablas/políticas ni cambios de Storage: 16 públicas, 5 privadas,
50 ingredientes, 74 alias. Añade índice parcial `(custom_key,recipe_id)` para
texto libre; el índice existente `(ingredient_id,recipe_id)` cubre catálogo.

`cook_today_page(p_ids uuid[], p_names text[], p_mode text, p_after jsonb,
p_limit integer)` devuelve `setof jsonb`. Es **SECURITY INVOKER**, estable,
`search_path` vacío y EXECUTE solo para authenticated. Usa las políticas
históricas de recetas, componentes, catálogo/alias y perfiles. Esta elección
mantiene la autoridad del llamante conforme a la [documentación de funciones
Supabase](https://supabase.com/docs/guides/database/functions).

Valida Auth, máximo combinado 50 entradas brutas, nombres no vacíos de hasta
80 caracteres, UUID de catálogo aprobado, modo exact/near, límite 1–50 y cursor
completo/tipado con exactamente cuatro campos. Nulls inválidos se rechazan.
No usa SQL dinámico, ILIKE ni interpolación. Vacío devuelve cero sin evaluar
recetas. El cliente también omite esa llamada.

## Comparación y orden

El [contrato exacto del algoritmo](06_MATCHING_ALGORITHM.md) define conjuntos
de claves, opcionales, ranking, tiempos y cursor. Se parte de componentes
autorizados con al menos una clave obligatoria coincidente, se evalúan sus
recetas en el servidor y se devuelve solo la página. No se descargan todas las
recetas, sus pasos o todos sus ingredientes al dispositivo.

Una única fuente de recetas bajo RLS ya contiene públicas propias/ajenas y
privadas propias. Un guardado no se une como otra fuente ni amplía permisos;
por eso no crea duplicados. Tampoco se devuelve un total global del catálogo
de recetas o recuentos de contenido inaccesible.

Cabecera `Recipe`, autor `PublicProfile`, required/matched/missing,
optional_matched, cursor y líneas obligatorias faltantes. La tarjeta muestra
foto autenticada, título, autor, categoría, tiempo, coincidentes/faltantes y
estado «Puedes prepararla» / «Te falta 1 ingrediente» / «Te faltan 2 ingredientes».
La explicación de cantidades de casa acompaña ambos modos.

## Paginación, revisión y límites

El repositorio pide 8+1; ocho tarjetas y novena fila detectan continuación.
Cursor de ranking completo, sin OFFSET. El controlador deduplica IDs al unir
páginas. Una edición puede cambiar el orden entre consultas: refrescar empieza
de nuevo; no se promete snapshot estable frente a escrituras concurrentes.

Las consultas se cancelan con `PostgrestBuilder.abortSignal` al liberar el
proveedor; generaciones y actor descartan páginas tardías. El transporte
cancelable existente se reutiliza. Cancelar no deshace una consulta que ya
terminó en servidor. Errores se muestran y se reintentan explícitamente.

La revisión compartida reconcilia CRUD/eliminación/publicación/bloqueos locales.
Se refresca al abrir/regresar del detalle, reactivar la pestaña, recuperar
foreground, pedir actualización y cada 30 segundos visible con backend real.
Durante carga/error no se muestran filas antiguas. Fotografías usan los
proveedores de Fase 04 y sus controles de referencia/identidad/desalojo.
Los cambios de otras sesiones pueden seguir en un frame descargado hasta
revalidar. No se promete revocar copias ni URLs firmadas externas vigentes.

El benchmark local usa 6.000 recetas/18.000 ingredientes/6.000 pasos dentro de
una transacción con rollback, llamando como rol authenticated. Páginas de nueve
registros: exact 1.911 s, near 3.138 s, siguiente 3.637 s en esa ejecución.
[Salida real](reports/phase06/evidence/matching-benchmark.txt). No son métricas
de producción ni una prueba de Auth de GoTrue; el cliente real A/B/C se verifica
por separado. No se crea caché privilegiada o tabla permanente para acelerarlo.

## Contrato de faltantes para Fase 07

`MissingIngredientsTransfer` contiene recipeId, recipeVersion y líneas tipadas
`MissingIngredient`: UUID original de la línea, ordinal, UUID canónico original
o nombre libre, UUID efectivo resuelto si procede, nombre, cantidad/unidad
**requerida por la receta**. Las líneas conservan su orden e identidad original;
no son cantidades de existencias domésticas. La lista del DTO es inmutable.

No existe botón de compra ni escritura en listas. Fase 07 deberá revalidar
acceso y versión antes de importar los ordinales mediante el contrato existente,
elegir una lista autorizada y confirmar. No transferir metadatos privados de
una receta a colaboradores. La aprobación de esa fase continúa pendiente.

## Reproducción y evidencia

PowerShell 7, Docker >=28, exclusivamente `mixtick-phase02`. Adaptador loopback
antes de iniciar, comprobación de bindings/listeners/probes antes de fixtures.
Reset solo con cero cuentas. Nunca ejecutar estos helpers contra Supabase remoto.

```powershell
.\scripts\verify_matching.ps1 -BackendChecks -ResetLocal -IncludeNative -IncludeAndroidBuild
# -IncludeNative requiere Pixel_10a arrancado; todas las salidas son de phase06.
# Solo backend y sus regresiones:
.\scripts\verify_matching.ps1 -BackendChecks -BackendOnly
```

Los scripts retiran únicamente las identidades/rutas de sus manifiestos
ignorados; config Auth se restaura y solo el stack del proyecto se apaga.
`benchmark_matching.sql` requiere proyecto vacío y revierte todo al terminar.

Pruebas, fallos iniciales, capturas, códigos reales y límites finales:
[informe Fase 06](reports/PHASE_06_REPORT.md). Mocks de UI no prueban RLS;
fixtures SQL y GoTrue A/B/C son evidencias distintas. iOS, móvil físico,
remoto/CDN/Realtime, worker, eliminación completa de cuenta y moderación
operativa conservan sus requisitos pendientes de lanzamiento.
