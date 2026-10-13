# Comunidad y guardados — Fase 05

La Comunidad utiliza únicamente recetas reales publicadas por usuarios. Las
cuatro pestañas se conservan; comentarios, perfiles y bloqueos son rutas
auxiliares. No hay recomendaciones, rankings, clonación, mensajería ni push.

## Consultas y modelos

`features/community` separa DTO tipado, contrato de repositorio, implementación
Supabase, proveedores y UI. `CommunityEntry` contiene el modelo `Recipe` de
Fase 04, `PublicProfile` de Fase 03, publicación y estado/recuentos sociales.
No se crea otro modelo de receta ni se copia contenido al guardar.

La migración **20261013000900_community_projection.sql** conserva 001–008.
No añade tablas públicas: siguen 16. Añade un ledger técnico privado de
solicitudes de comentario: son 5 tablas privadas. Conserva las políticas y
grants históricos, los RPC de recetas, Storage, quotas y todos los contratos
de Auth, compra y agregado de Mi recetario.

| RPC nuevo | Contrato |
|---|---|
| `community_page` | `p_search`, categoría exacta, username del autor, `p_saved`, cursor publicación/UUID, límite 1–50 y filtro opcional por receta. Devuelve cabecera tipada, autor mínimo y recuentos/flags calculados por servidor |
| `community_categories` | Categorías distintas de recetas públicas autorizadas |
| `community_author(p_username)` | Perfil mínimo, UUID relacional interno para acciones, seguidores/seguidos visibles y flag propio |
| `create_comment_once(p_id,p_recipe_id,p_content)` | `p_id` es un request UUID del actor, **no** el ID del comentario. Public wrapper invoker → implementación privada cerrada. El servidor genera el ID del comentario |

Las tres proyecciones son **SECURITY INVOKER**. RLS se aplica también a perfiles,
ingredientes, likes, comentarios, seguimientos y guardados usados dentro de
las consultas. Los recuentos excluyen interacciones de usuarios bloqueados
para el observador; no son un total global privilegiado. No hay vista definer
ni bypass de RLS. Anon no tiene EXECUTE. Estos criterios siguen la
[documentación oficial de funciones](https://supabase.com/docs/guides/database/functions)
y [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).

El feed obtiene ocho registros y un noveno para detectar continuación en una
petición de metadata. No hace una consulta social o de autor por tarjeta. Fotos
y avatares requieren descarga autenticada aparte; se reutilizan proveedores por
path. La foto conserva la comprobación previa de receta/referencia de Fase 04.
No se afirma rendimiento medido con grandes volúmenes de producción.

## Orden y búsqueda

Feed, recetas del autor y guardados ordenan por `published_at DESC, id DESC`.
El cursor usa el par exacto de la última fila; la publicación inicial es estable,
también al republicar. 009 añade el índice en ambos campos descendentes. Los
controladores deduplican IDs al unir páginas. Nuevas publicaciones concurrentes
se recuperan con refresh; no hay garantía de snapshot entre páginas.

Una búsqueda general combina por OR:

- Título y categoría: subcadena normalizada por el servidor, sin distinguir
  tildes/mayúsculas/espacios repetidos. `%` y `_` son caracteres literales.
- Ingrediente de catálogo: nombre completo o alias completo aprobado, resuelto
  por `ingredient_aliases` hacia el ingrediente canónico. «tomates» = «Tomate».
- Texto libre: igualdad del nombre completo normalizado con `custom_key`.

No se singulariza automáticamente, no se deducen sustituciones y no se equiparan
leche/nata, pimientos distintos o «aceite» ambiguo. Un fragmento puede encontrar
un título/categoría, pero no implica equivalencia de ingrediente. La UI explica
esta cobertura. Todos los candidatos proceden de recetas **públicas** bajo RLS,
incluso los propios privados se excluyen del feed. Este buscador no implementa
el algoritmo futuro de «¿Qué cocino hoy?».

Debounce de 350 ms, paginación progresiva al desplazarse, botón de reintento,
pull-to-refresh y estados vacíos/error/carga. Las consultas obsoletas se cancelan
con `PostgrestBuilder.abortSignal` y el cliente HTTP cancelable aprobado. Además,
generaciones, autoDispose y comprobaciones de identidad descartan resultados
obsoletos. No se promete deshacer una petición ya ejecutada en el servidor.

## Interacciones y comentarios

Likes, saves, follows y blocks reutilizan INSERT/DELETE, defaults de Auth y PK
históricas. Repetir una inserción con duplicado de PK es seguro; no se modifican
contadores en Flutter. Borrar se limita al actor. La UI serializa envíos, espera
la operación y reconsulta servidor en éxito **o error ambiguo**; no es optimista.
Los prechecks de acceso/identidad no sustituyen RLS; después de cada await previo
a una escritura se verifica que el actor sigue siendo el original.

Comentarios: texto plano de 1–2000 caracteres, autor/fecha, páginas recientes
de 8+1 y borrado propio con confirmación. No hay edición, hilos ni respuestas.
009 rechaza texto compuesto solo por espacios/tabuladores/saltos mediante CHECK
aditivo, también para INSERT directo. Se conserva el límite de 20 creaciones
por minuto, que no se reinicia al borrar.

`private.comment_creation_requests` usa PK `(actor_id,request_id)`, RLS, sin grants
de cliente. Guarda hash de receta/texto y referencia al comentario. Misma solicitud
con mismo contenido devuelve la referencia; un payload diferente o tombstone de
comentario borrado produce PT409. El actor procede de `auth.uid()`. El ledger
impide duplicar tras perder una respuesta y evita que un UUID proporcionado
sirva para consultar la existencia de un comentario ajeno. INSERT directo
histórico permanece disponible; no tiene idempotencia de solicitud.

## Guardados, detalle y perfiles

Mi recetario tiene «Creadas por mí» y «Guardadas». La segunda usa la misma
proyección con `p_saved=true`; admite búsqueda, categoría, paginación y acceso
al detalle original. El guardado es únicamente `recipe_saves`, conserva autoría
y nunca concede permisos. Privatizar/borrar/bloquear elimina la fila visible;
un marcador interno invisible puede persistir. No hay «Crear mi versión».

El detalle reutiliza `recipe_detail_page.dart`/`RecipeContent`; conserva edición,
privacidad y borrado propios. En públicas presenta autor, likes, comentarios,
guardar ajenas, seguir autor y denuncia. La proyección social vuelve a validar
el acceso antes de mostrar el contenido público del detalle. Los perfiles de
Fase 03 se conservan y añaden controles sociales y sus recetas públicas.
No se muestran email, metadata Auth o datos editables ajenos.

## Moderación y límites de caché

Denuncia receta/comentario/perfil mediante `submit_report` existente, con motivo
seleccionado y resultado real. Validación de target/acceso, status y límite de
5 denuncias/minuto siguen en servidor. No se añade panel administrativo. La
moderación operativa continúa pendiente del lanzamiento.

Bloquear es simétrico para las lecturas/interacciones históricas. Desbloquear
retira solo el bloqueo creado por el usuario; un bloqueo inverso puede continuar
ocultando el perfil. La lista propia de bloqueos no elude RLS de perfiles: muestra
una etiqueta y un fragmento del identificador relacional de cada bloqueo; no
recupera nombres/avatar mediante consultas privilegiadas o cachés persistentes.

Los cambios locales invalidan feed, guardados, autor, detalle y fotos a través
de una revisión compartida. Cambiar identidad elimina borradores/diálogos y
estado visible por `SessionScope`; generaciones descartan acciones tardías.
Los proveedores de fotos/avatares desalojan sus `MemoryImage` al invalidarse.
No hay URLs firmadas emitidas por la app ni caché persistente de fotografías.

Al abrir un detalle, regresar de otra ruta, activar de nuevo el feed/guardados,
refrescar o recuperar foreground se consultan permisos y se ocultan datos
anteriores durante carga/error. Las pantallas visibles con backend real
revalidan también cada 30 s. Realtime social no está habilitado: cambios realizados
por **otra sesión** pueden seguir visibles en el frame ya descargado hasta esa
revalidación; ningún nuevo acceso al servidor obtiene permisos extra. No se
promete revocación visual instantánea de una copia ya obtenida. Los límites de
capacidad temporal/bytes de [Storage](15_STORAGE_SECURITY.md) siguen vigentes.

## Reproducir verificaciones

Ejecutar solo en `mixtick-phase02`, con Docker >=28 y el adaptador loopback;
el runner comprueba bindings, listeners y probes de otras interfaces antes de
crear fixtures. Un reset se rechaza si existen cuentas. No usar backend remoto.

```powershell
.\scripts\verify_community.ps1 -BackendChecks -ResetLocal -IncludeAndroidBuild
# Emulador Pixel_10a iniciado; añadir ambas integraciones Android y capturas:
.\scripts\verify_community.ps1 -BackendChecks -ResetLocal -IncludeNative -IncludeAndroidBuild
```

SQL estructural/RLS API real, clientes Auth anteriores en ambos modos de correo,
cliente recetas anterior, cliente Comunidad A/B/C, widgets/mocks y Android se
distinguen en el [informe de Fase 05](reports/PHASE_05_REPORT.md). Las dos pruebas
de sockets usan actor/servidor de transporte de test: no prueban Auth/RLS.
Los casos cliente de pérdida de transporte y lectura retrasada son híbridos
identificados; todas sus operaciones de producto/Auth sí alcanzan servidor real.

La limpieza host de `cleanup_community_fixtures.py` valida manifiesto ignorado,
UUID/email p5 example.test, rutas y propietarios. Retira solo objetos/cuentas
de esa ejecución mediante Storage API local privilegiada; la clave no entra
en Flutter ni pruebas de permisos. No equivale a un worker de producción.
Config Auth se restaura y el runner apaga solo el stack del proyecto.
iOS, físico, remoto/CDN/Realtime, worker, eliminación de cuenta y moderación
operativa continúan pendientes. No hay autorización de Fase 06, Git o deploy.
