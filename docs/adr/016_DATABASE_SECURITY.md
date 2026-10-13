# ADR-016 — Esquema, autoridad y operaciones atómicas

Fecha: 2026-10-13. Estado: implementada localmente en Fase 02.

Se conserva Foundation y sus identificadores sin cambiar código Flutter,
plataformas ni dependencias. La fase implementa exclusivamente SQL, configuración
local, pruebas y documentación. El prompt existente es `02_DATABASE_SECURITY.md`;
`02_DATABASE.md` citado en la autorización no existe en el paquete.

Se adoptan 16 tablas públicas (14 solicitadas + bloqueo/denuncias transversales)
y 3 tablas técnicas privadas. No se añaden módulos visibles. RLS se activa en
las 19, con grants mínimos y control de columnas. Helpers de autorización y
definer transaccionales se alojan en `private`, con `search_path = ''`, identidad
de auth.uid() y permisos de ejecución explícitos. RPC públicas son invoker.
Esto evita ciclos RLS y entrada directa a funciones internas privilegiadas.

Recetas se crean completas y private por RPC; publicación es otra acción.
Guardados/likes pueden permanecer tras despublicación pero las lecturas se
ocultan. Alias se resuelven a UUID incluso si llegan como texto libre conocido;
el fallback desconocido se normaliza sin contaminar el catálogo. Plurales y
sinónimos se curan explícitamente para no mezclar ingredientes distintos.

Edición usa versiones de servidor. Conflictos intencionados responden PT409;
usar 40001 producía HTTP 500 en PostgREST, lo que detectó la prueba concurrente.
Lista es el primer bloqueo de las operaciones de miembros/productos. Aceptación
es atómica/idempotente y una revocación no puede resucitarse por reintento.

Importación conserva solo nombre/cantidad/unidad/catalog ID en productos, sin
título/notas/ID de receta. Ledger y contadores son privados. Las cuotas se
mantienen aunque el usuario borre contenido. Los errores de ítem desconocido
e ítem ajeno son iguales para evitar una consulta de existencia lateral.

Fotos permanecen en bucket privado; RLS sigue a receta. Se prefiere descarga
autenticada; TTL recomendado de URL firmada 60 s, con límite real documentado:
RLS no impone un TTL máximo a un cliente previamente autorizado. No se promete
revocación de URLs ya emitidas ni borrado físico de blobs por una cascada SQL.
Hay cola privada de limpieza; su trabajador debe implementarse antes de distribuir.

Solo INSERT/UPDATE de listas/productos se publican en Realtime. DELETE se
excluye por no poder reevaluar RLS de una fila ya borrada. Versión de lista
notifica cambios para una recarga autoritativa posterior. Los flujos WebSocket
y reconexión se verifican en Fase 07, no se declaran hechos ahora.

Herramientas: Docker Desktop existente arrancado, Supabase CLI 2.120.0 portátil
con SHA256 oficial contrastado. Proyecto dedicado `mixtick-phase02`, red Docker
propia y peticiones de prueba exclusivamente a 127.0.0.1; no login/link ni operaciones remotas. PostgreSQL, GoTrue,
PostgREST y Storage reales se usan para pruebas A/B/C. Solo public anon y tokens
de usuarios en peticiones API; SQL postgres únicamente para introspección,
pruebas estructurales, cola y limpieza de fixtures locales.

La comprobación real de puertos detectó 0.0.0.0/[::] pese a la opción de red
host_binding_ipv4=127.0.0.1 recomendada por la documentación. No se afirma
aislamiento del listener. Se apaga únicamente este stack al cerrar la fase.
El runner también apaga el stack que arranca salvo `-KeepLocalRunning` explícito.
Para repetir pruebas hace falta un entorno de confianza/restringido; no se
modificó el firewall ni configuración global de Docker.

Referencias oficiales: [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[funciones](https://supabase.com/docs/guides/database/functions),
[errores HTTP de PostgREST](https://docs.postgrest.org/en/stable/references/errors.html),
[desarrollo local](https://supabase.com/docs/guides/local-development).
