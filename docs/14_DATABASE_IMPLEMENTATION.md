# Esquema implementado — Fase 02

Fuente ejecutable: seis migraciones `20261013000100` a `20261013000600` en
`supabase/migrations/`. PostgreSQL local 17 y Supabase CLI 2.120.0. Las cuatro
funcionalidades siguen siendo Comunidad, Mi recetario, ¿Qué cocino hoy? y
Lista de compra; Auth, perfil, bloqueo y denuncia son soporte transversal.

## Tablas de producto y soporte

| Tabla | Clave y relaciones | Integridad / escritura del cliente |
|---|---|---|
| profiles | PK user_id → auth.users | Username ASCII minúsculo único (3–30), display_name 1–60, sin email. INSERT/UPDATE limitado a username/display_name/avatar_path propios |
| ingredients | PK UUID, normalized_key generado único | Catálogo aprobado de solo lectura; nombres 1–80 |
| ingredient_aliases | PK UUID, FK ingredient_id → ingredients | normalized_alias generado único; no puede apuntar al ingrediente equivocado si colisiona con un nombre canónico |
| recipes | PK UUID, author_id → profiles | Private por defecto; título 1–120; categoría 1–60; raciones positivas; tiempos no negativos; versión de servidor. Create/update completos vía RPC; DELETE solo propietario |
| recipe_ingredients | PK UUID, FK recipe_id y ingredient_id opcional | XOR catálogo/texto libre; quantity positiva opcional; unit opcional; optional; sort_order 0–99 único por receta |
| recipe_steps | PK UUID, FK recipe_id | Instrucción 1–4000 y sort_order 0–99 único por receta |
| recipe_saves | PK (user_id, recipe_id) | Sin duplicados; solo referencias propias y legibles; insertar solo en pública accesible |
| recipe_likes | PK (user_id, recipe_id) | Sin duplicados; lecturas sujetas a receta y bloqueos; insertar solo en pública accesible |
| recipe_comments | PK UUID, FKs recipe_id/author_id | Texto 1–2000; editar/borrar propio; lectura hereda receta y bloqueo |
| user_follows | PK (follower_id, followed_id) | Sin duplicados/autoseguimiento; identidad propia inmutable |
| user_blocks | PK (blocker_id, blocked_id) | Sin autobloqueo; cada usuario solo ve y gestiona sus bloques |
| content_reports | PK UUID, FK reporter_id; target_type/id | Targets recipe/comment/profile validados por RPC; razón 10–1000; status no editable por cliente |
| shopping_lists | PK UUID, owner_id → profiles | Título 1–120; propietario inmutable; crear/renombrar/borrar propia |
| shopping_list_members | PK (list_id, user_id) | Solo aceptación de invitación crea miembro; propietario no se duplica; revocación/abandono por RPC |
| shopping_list_invitations | PK UUID, FKs list_id/sender_id/invitee_id | Una pending por lista/destinatario; remitente debe ser dueño; identidad inmutable; empieza pending; receptor responde |
| shopping_items | PK UUID, FK list_id, ingredient_id opcional | Datos copiados sin origen de receta; quantity positiva; source_key opaca única por lista; todas las escrituras por RPC con autorización de lista |

`version` y `updated_at` se gestionan con triggers en profiles, recipes,
recipe_comments, shopping_lists y shopping_items. El cliente no puede asignar
identidades, timestamps, versiones, miembros ni estado de moderación mediante
los grants de columnas. Las escrituras del SDK deben respetar estos contratos.

## Catálogo y normalización

Hay 50 ingredientes aprobados y 74 entradas de alias (50 nombres canónicos y
24 variaciones explícitas). Los UUID iniciales son deterministas. Se normalizan
case, acentos y espacios con unaccent y lowercase. Los plurales son aliases
curados: no se elimina una «s» genéricamente ni se infieren equivalencias.

`resolve_ingredient('  tOMÁTES  ')` devuelve el mismo UUID que «Tomate».
`save_recipe` convierte un nombre libre reconocido en FK canónica. Si no está
reconocido, conserva texto libre con `custom_key` normalizada; no crea una fila
en el catálogo. No se fusionan nata/leche, aceites diferentes, pimientos
rojo/verde ni pimentón dulce/picante. «Aceite», «harina» y «pimiento» genéricos
no se resuelven silenciosamente.

La consulta de ingredientes de casa sigue siendo efímera y no se guarda en
ninguna tabla. No hay inventario ni comprobación de cantidades disponibles.

## Permisos

Anon no puede leer tablas de producto ni ejecutar RPC. Usuarios autenticados
ven perfiles públicos sin email y catálogo aprobado, respetando bloqueos.
Los helpers de RLS están en `private`, derivan el usuario de `auth.uid()`, tienen
`search_path = ''` y bypass acotado a consultas de autorización. No aceptan una
identidad arbitraria del solicitante y no hay ciclos entre políticas.

Una receta es accesible para su autor, o si es pública para otro autenticado sin
bloqueo entre ambos. Ingredientes, pasos, likes, comentarios y guardados heredan
la privacidad vigente. Guardados son privados para quien guarda; una referencia
inaccesible puede persistir físicamente pero desaparece de todas sus lecturas.
Cambiar a private no borra los marcadores ni permite usarlos como bypass.

Dueño y miembros aceptados sin bloqueo al dueño ven listas/productos. Invitados
pending pueden leer su invitación pero no la lista/productos. Ser destinatario
de una invitación no crea membresía implícita. Miembros no invitan, renombrar ni
borran la lista. Revocar elimina la membresía y marca invitaciones activas como
revoked; no se puede reutilizar una aceptación antigua para recuperar acceso.

## RPC y transacciones

Todos los entry points públicos son SECURITY INVOKER; delegan a implementaciones
privadas SECURITY DEFINER con usuario, permisos y `search_path` validados.
PUBLIC/anon no tienen EXECUTE. Helpers internos de bloqueo/trigger no son
ejecutables por authenticated. `private` no se expone en la API local ni debe
añadirse a los esquemas expuestos de un proyecto remoto.

| RPC | Argumentos / resultado | Contrato |
|---|---|---|
| resolve_ingredient | p_name → UUID o null | Alias exacto normalizado; catálogo aprobado y RLS |
| save_recipe | p_recipe_id, p_expected_version, p_recipe, p_ingredients, p_steps → UUID | ID null crea private; edición requiere versión y autor. Entre 1 y 100 ingredientes/pasos; fallo revierte cabecera y relaciones |
| set_recipe_visibility | p_recipe_id, p_visibility, p_expected_version → bigint | Autor; publicación explícita; primera published_at se conserva al republicar |
| set_recipe_photo | p_recipe_id, p_path, p_expected_version → bigint | Autor; objeto existente y ruta ligada a autor/receta |
| invite_to_list | p_list_id, p_username → UUID | Dueño; usuario registrado no bloqueado; no invitarse ni duplicar pending |
| respond_to_invitation | p_invitation_id, p_accept → UUID | Solo receptor; respuesta atómica; reintento aceptado idempotente mientras sea miembro |
| revoke_list_member | p_list_id, p_user_id → void | Solo dueño; también revoca invitaciones pending/accepted del destinatario |
| leave_list | p_list_id → void | Miembro abandona y revoca su aceptación; dueño no abandona |
| add_shopping_item | p_list_id, p_item → UUID | Dueño/miembro; valida producto y catálogo opcional |
| update_shopping_item | p_item_id, p_expected_version, p_changes → bigint | Solo name/quantity/unit/is_purchased; conflicto de versión HTTP 409 |
| delete_shopping_item | p_item_id, p_expected_version → void | Permiso vigente y versión; actualiza versión de lista |
| import_recipe_ingredients | p_list_id, p_recipe_id, p_request_id, p_ordinals? → UUID[] | Selección válida y receta accesible; inserción completa atómica e idempotente |
| submit_report | p_target_type, p_target_id, p_reason → UUID | Target existente y accesible; no permite asignar estado de moderación |

Las RPC void responden HTTP 204. Validaciones responden 400, permisos 403,
duplicados 409; conflictos de versión usan SQLSTATE PT409 según PostgREST.
Se bloquea primero la lista, luego invitación/ítem. La misma versión no puede
sobrescribirse dos veces: una edición concurrente gana y otra debe recargar.
Recipe aggregate también bloquea su cabecera y valida versión antes de reemplazar
relaciones. Importación bloquea lista y receta; su request_id se serializa.

## Tablas técnicas privadas

| Tabla | Finalidad / privacidad |
|---|---|
| private.shopping_imports | PK actor/request, FK lista, hash de payload, IDs de líneas. No guarda título/notas ni UUID de receta en claro y no se expone a miembros |
| private.storage_cleanup_jobs | Bucket/ruta a eliminar tras borrar una receta; solo backend de confianza. El trabajador físico de limpieza está pendiente |
| private.creation_windows | Contadores atómicos por usuario/recurso durante 60 s desde su primer envío. Persisten aunque se borre contenido; no expuestos |

El `source_key` visible en compra usa un hash de actor/request y ordinal; no
incluye identificadores ni metadatos de recetas. Repetir el request con el mismo
payload devuelve IDs originales. Cambiar payload con ese request se rechaza.
Si una línea ya se borró, reintentar no la resucita. Una nueva acción necesita
nuevo request_id. No se fusionan cantidades de productos automáticamente.

Límites mínimos de creación por cuenta/ventana de 60 segundos: 10 recetas,
20 comentarios, 20 listas, 20 invitaciones y 5 denuncias. Exceso: HTTP 429.
No son una auditoría de abuso completa ni sustituyen límites del servicio Auth.

## Borrado y fotografías

Auth user → profile → recetas/listas y filas dependientes usan cascada. Al borrar
una lista, se borran miembros, invitaciones, productos y ledger. Catálogo
referenciado por receta/producto no se puede borrar (RESTRICT). Borrar receta
elimina relaciones sociales y componentes. Denuncias polimórficas conservan
target_id para revisión, sin datos originales del contenido eliminado; al borrar
reporter se elimina su informe. No hay transferencia automática de listas de una
cuenta eliminada: la política inicial es borrar sus listas; UX debe explicarla.

Los blobs se eliminan mediante API Storage por un backend de confianza, nunca
borrando solo metadata storage.objects por SQL. La cola preparada evita olvidar
archivos al borrar una receta/cuenta. La implementación del trabajador y el flujo
completo de eliminación de cuenta siguen pendientes antes de distribuir.
La política Storage deniega lecturas desde que la receta deja de existir.
Véase [privacidad de fotos](15_STORAGE_SECURITY.md).

## Realtime

Se publican únicamente shopping_lists y shopping_items, INSERT/UPDATE, con
replica identity default. Se excluyen DELETE porque una fila borrada ya no puede
reevaluar RLS y no debe difundir metadata a terceros. Cada modificación/borrado
de un ítem y cambio de miembros incrementa version/updated_at de lista. Usuarios
que siguen autorizados podrán recibir esa actualización y recargar su lista.

Realtime es aviso; PostgreSQL es autoridad. Reconexión/errores de permiso deben
recargar o vaciar estado autorizado en Fase 07. No se ha verificado un cliente
WebSocket ni el flujo de reconexión: solo publicación y permisos por API.
