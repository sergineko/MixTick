# Informe final FASE 02

Fecha: 2026-10-13, Europe/Madrid. Plantilla: `templates/PHASE_REPORT.md`.

- **Objetivo:** implementar exclusivamente base de datos y seguridad de MixTick,
  conservar Foundation y sus identificadores, verificar RLS con A/B/C reales
  antes de desarrollar interfaces funcionales.
- **Resultado:** **VERIFIED en Supabase local**. Seis migraciones desde cero,
  19 comprobaciones pgTAP y 20 escenarios reales de Auth/PostgREST/Storage PASS.
  Lint SQL final sin avisos. Analyze y 21 tests Flutter PASS; IDs estrictos PASS.
  **NOT_VERIFIED**: backend remoto/CDN/cliente Realtime y trabajador físico de
  limpieza. **NOT_RUN**: compilación iOS y flujos Flutter de fases posteriores.
- **Cambios de código:** sin cambios en `lib/`, `test/`, Android/iOS,
  `pubspec.yaml` ni `pubspec.lock`. La [comparación de Foundation](phase02/evidence/foundation-diff.txt)
  está vacía. Las interfaces de negocio continúan indicando «Próximamente».

| Área | Archivos reales creados/modificados |
|---|---|
| Supabase local | `supabase/config.toml`, `supabase/.gitignore`, `supabase/README.md`, `supabase/seed.sql` |
| Esquema | `supabase/migrations/20261013000100_schema.sql` |
| RLS/grants | `supabase/migrations/20261013000200_rls.sql` |
| RPC/transacciones | `supabase/migrations/20261013000300_transactions.sql` |
| Fotos/Realtime | `supabase/migrations/20261013000400_storage_realtime.sql` |
| Catálogo | `supabase/migrations/20261013000500_ingredient_catalog.sql` |
| Integridad/límites | `supabase/migrations/20261013000600_integrity_limits.sql` |
| Pruebas SQL | `supabase/tests/001_structure.test.sql` |
| Herramientas/test API | `scripts/install_supabase_cli.ps1`, `scripts/verify_database.ps1`, `scripts/test_database_api.py` |
| Documentación | `README.md`, `docs/04_DATA_MODEL.md`, `docs/10_DECISIONS.md`, `docs/PROGRESS.md`, `docs/14_DATABASE_IMPLEMENTATION.md`, `docs/15_STORAGE_SECURITY.md`, `docs/adr/016_DATABASE_SECURITY.md`, este informe y `docs/reports/phase02/evidence/` |

- **Migraciones/backend:** ejecutadas **solo** en el proyecto Docker local
  `mixtick-phase02`. PostgreSQL real **17.11**, Supabase CLI **2.120.0**, Docker
  **29.8.1**. No se realizaron login/link, db push, deploy ni operaciones sobre
  Supabase remoto. [Auditoría real del esquema y fixtures](phase02/evidence/database-audit.json).

| ID | Contenido y evidencia de ejecución |
|---|---|
| 20261013000100 | 16 tablas públicas, FK/CHECK/índices, versión/timestamps, tablas privadas de idempotencia/limpieza y triggers |
| 20261013000200 | RLS, grants por columna y helpers privados sin recursión; anon denegado |
| 20261013000300 | Receta completa, publicación explícita, foto, invitaciones/miembros, productos versionados, importación y denuncias; wrappers invoker y validación backend |
| 20261013000400 | Bucket `recipe-photos` privado, políticas heredadas de receta, publicación Realtime limitada a INSERT/UPDATE de listas/productos |
| 20261013000500 | 50 ingredientes españoles aprobados y 74 nombres/aliases, UUID reproducibles; sin cuentas ni contenido ficticio en el seed |
| 20261013000600 | Remitente/identidad de invitación y propietario no duplicado como miembro; contadores privados y límites de creación atómicos |

Son 16 tablas de producto/soporte: las 14 solicitadas más `user_blocks` y
`content_reports`, previstas en la especificación original. Las 3 privadas son
`shopping_imports`, `storage_cleanup_jobs` y `creation_windows`: no son módulos
visibles y no se exponen por API. RLS activada en las 19.

- **Comandos ejecutados:** tabla con códigos reales finales. `<CLI>` es
  `C:\Users\Sergio\Desktop\Proyectos\MixTick\.tooling\supabase\supabase.exe`;
  `<PY>` es el Python 3.12.14 funcional del runtime de Codex. `<NET>` es el ID
  completo de `mixtick-local-tests`, obtenido con `docker network inspect`.
  Argumentos exactos, códigos y horas constan en
  [reset definitivo](phase02/evidence/results-fresh-reset.json),
  [runner final](phase02/evidence/results.json) y
  [comprobaciones Flutter/ejecución intermedia](phase02/evidence/results-full-checks.json).
  Este último conserva el lint intermedio como FAIL por sus avisos, aunque el
  proceso devolvió 0; no debe confundirse con el lint final limpio.

| Comando | Código | Estado y resultado verificable |
|---|---:|---|
| `<CLI> --version` | 0 | PASS: 2.120.0; [salida](phase02/evidence/cli-version.txt) |
| `docker version --format '{{.Server.Version}}'` | 0 | PASS: 29.8.1; [salida](phase02/evidence/docker-version.txt) |
| `<CLI> init` | 0 | PASS: configuración local generada; `private` fuera de schemas expuestos, auto_expose_new_tables=false |
| `<CLI> start --network-id <NET> -x studio,imgproxy,edge-runtime,logflare,vector,supavisor,postgres-meta` | 0 | PASS: servicios reales locales; salidas privilegiadas de setup redactadas |
| `<CLI> db reset --local --network-id <NET>` | 0 | PASS: seis migraciones desde cero y seed; [salida](phase02/evidence/db-reset.txt) |
| `<CLI> migration up --local --network-id <NET>` | 0 | PASS: ejecución intermedia de 006; [salida](phase02/evidence/migration-up.txt). Reset final confirma las seis juntas |
| `<CLI> test db --network-id <NET>` | 0 | PASS: 19 tests pgTAP; [salida](phase02/evidence/sql-tests.txt) |
| `<CLI> db lint --local --level warning --network-id <NET>` | 0 | PASS: `No schema errors found`, `results: []`; [salida final](phase02/evidence/db-lint.txt) |
| `<PY> scripts/test_database_api.py --cli <CLI>` | 0 | PASS: 20 tests, 0 failures/errors/skipped; [salida](phase02/evidence/api-tests.txt), [resultado](phase02/evidence/api-results.json) |
| `flutter analyze` | 0 | PASS: `No issues found! (ran in 8.4s)`; [salida](phase02/evidence/flutter-analyze.txt) |
| `flutter test --reporter expanded` | 0 | PASS: 21 pruebas; [salida](phase02/evidence/flutter-test.txt) |
| `dart format --output=none --set-exit-if-changed lib test` | 0 | PASS: 27 archivos, 0 cambios; [salida](phase02/evidence/format-check.txt) |
| `<PY> scripts/check_identifiers.py --strict` | 0 | PASS: `mixtick`, namespace/applicationId/MainActivity y 3 configuraciones iOS correctas; [salida](phase02/evidence/identifiers.txt) |
| Auditoría SQL real mediante `docker exec ... psql` | 0 | PASS: 6 versiones migradas, 16+3 tablas, 50/74 catálogo; cero fixtures restantes; [resultado](phase02/evidence/database-audit.json) |
| `<CLI> stop --project-id mixtick-phase02` | 0 | PASS: parada exclusiva del proyecto, backup conservado; [salida](phase02/evidence/local-stop.txt) |
| `docker ps --filter name=mixtick-phase02` tras parada | 0 | PASS: cero contenedores/puertos de este stack; [comprobación](phase02/evidence/local-stop-verification.txt) |

Python y Flutter se ejecutaron por sus rutas absolutas instaladas, conservadas
en los JSON de resultados; no se fingió disponibilidad de los aliases Python
de WindowsApps. La descarga oficial portátil de CLI verificó SHA256
`53920013d24bc9e66180f35ceeea9ddc20e65a7afa883421e9c0ba60ad7457ee` antes de extraer.
No se instaló otro runtime global ni se cambió PATH en esta fase.

- **Pruebas:** 20 casos reales de backend + 19 de estructura SQL + 21 Flutter.
  A/B/C se crearon por GoTrue/Auth con signup local, correo ficticio example.test
  y credenciales aleatorias. Peticiones de producto/fotos solo con clave pública
  anon y JWT de esas cuentas. No se usaron mocks ni service_role para demostrar
  permisos. PostgreSQL postgres se usó para introspección/pgTAP, el trigger de
  cola en transacción con rollback y limpiar exclusivamente las fixtures.

| Requisito del propietario / caso | Estado | Evidencia real |
|---|---|---|
| 1. A accede a su privada | PASS | test_01: receta nueva private incluso si el payload intenta public; A lee cabecera/relaciones |
| 2. B/C no acceden a privada | PASS | test_01: consultas directas y joins devuelven cero filas |
| 3. B accede al publicar | PASS | test_01: lectura de cabecera/ingredientes y creación de save/like/comment autorizadas |
| 4. B pierde acceso al privatizar | PASS | test_01: cabecera, ingredientes, pasos, guardados, likes y comentarios quedan ocultos; published_at estable al republicar |
| 5. Relaciones/fotos no filtran | PASS | test_01 y test_11: lecturas/listados/firma denegados, endpoint público cerrado, subida en ruta ajena denegada, URL caducada deja de servir bytes |
| 6. No modifica receta ajena | PASS | test_02: PATCH, DELETE y RPC ajenas denegadas; identidad de perfil no suplantable; sin escrituras directas de componentes |
| 7. B edita siendo miembro | PASS | test_04: aceptación real y cambio de producto visible a A |
| 8. C no consulta/modifica lista | PASS | test_04: listas, productos, miembros, invitaciones ocultos; añadir/editar/borrar por UUID conocidos denegados |
| 9. B pierde acceso al revocar | PASS | test_04: mismo JWT ya emitido no permite leer/añadir/editar/borrar; antigua invitación no restaura membresía |
| 10. Solo receptor acepta | PASS | test_05: A/C no aceptan la invitación de B; cuatro aceptaciones simultáneas crean una membresía; abandonar invalida aceptación |
| 11. Unicidad/referencias/integridad | PASS | test_03/06/09/13/15: rollback de receta completa, interacciones/invitaciones duplicadas rechazadas, FK inexistente/autoseguimiento rechazados, cascadas y selección inválida sin inserción parcial |
| 12. Sin recursión RLS | PASS | Todas las consultas anteriores, incluidas relaciones/miembros, completan sin 42P17/HTTP 500; helpers de política privados auditados |
| Concurrencia de productos | PASS | test_07: dos ediciones con misma versión producen 200 y 409; ninguna sobrescritura silenciosa ni bypass PATCH |
| Importación e idempotencia | PASS | test_08/09: dos peticiones concurrentes con mismo request crean 2 líneas; no origen privado; cambiar payload rechazado; retry no resucita una línea borrada |
| Catálogo normalizado | PASS | test_10/20: case/tildes/plural resuelven mismo UUID; conocidos enviados como texto se guardan por FK; nata/leche distintos; términos ambiguos no se infieren |
| Anon/esquema privado | PASS | test_12: anon denegado; private no expuesto por PostgREST |
| Bloqueos/denuncias | PASS | test_14/17: contenidos y perfiles bloqueados ocultos; report target inválido/status editable rechazados; invitación bloqueada/rechazada no da acceso |
| Límites de creación | PASS | test_16: 20 comentarios permitidos, siguiente 429 incluso tras borrar un comentario |
| Cola de fotos y existencia lateral | PASS | test_18: borrado real de receta en transacción encola objeto, rollback deja blob para limpieza normal; test_19: error de ítem ajeno e inexistente igual |
| Foundation | PASS | 21 tests previos, analyze/formato/IDs y diff vacío de código/plataformas/dependencias |

**Limpieza:** auditoría final: 0 usuarios Auth, profiles, recipes, shopping_lists,
objetos recipe-photos, ledger, trabajos de limpieza y ventanas de cuota de las
fixtures. Se mantienen exclusivamente los 50 ingredientes y 74 entradas de
alias. No se dejaron cuentas de prueba en ningún entorno remoto.

- **Seguridad:** autoridad en servidor; private por defecto; consultas de
  relaciones heredadas; grants mínimos y columnas de identidad inmutables;
  políticas sin recursión; definer con search_path vacío en esquema no expuesto;
  miembro solo tras aceptación del receptor; revocación comprobada usando su
  token existente. RPC públicas son invoker y no permiten un actor arbitrario.
  No hay claves administrativas en Flutter, Git ni las evidencias guardadas.
  La CLI devuelve claves de setup local; stdout bruto queda solo en `.tooling`
  ignorado y el runner redacta estas claves.
- **Limitaciones y riesgos:**

| Incidencia/límite | Tratamiento y estado |
|---|---|
| Prompt `02_DATABASE.md` ausente | Se utilizó el prompt equivalente real `02_DATABASE_SECURITY.md`; no se añadió otro alcance |
| Docker apagado y CLI ausente | Arrancado Docker existente; CLI portátil oficial verificada en `.tooling`. No instalación de componentes del sistema ni cambios remotos |
| Sandbox impedía escribir preferencia local de la CLI | Comandos locales ejecutados con permisos adecuados; sin afirmar ejecución si no arrancaban |
| db reset/test db sin red explícita | Fallos reales DNS/reinicio; preservados en [reset inicial](phase02/evidence/db-reset-initial.txt) y [pgTAP inicial](phase02/evidence/sql-tests-initial.txt). Corregidos pasando ID completo de red |
| INSERT RETURNING de lista propia denegado | La policy SELECT ahora permite owner_id actual directamente, además del helper de miembros. [Fallo inicial](phase02/evidence/api-tests-initial.txt); pruebas finales PASS |
| RPC void esperado como 200 | PostgREST responde 204; assertions corregidas sin relajar los permisos. [Ejecución intermedia](phase02/evidence/api-tests-intermediate.txt) |
| Conflicto de versión devolvía 500 | SQLSTATE 40001 se traduce a 500; se usa PT409 para conflicto intencionado. Test concurrente final confirma 200/409 |
| Dos avisos PL/pgSQL | Variable sin uso y array sin cast explícito; [lint inicial](phase02/evidence/db-lint-initial.txt). Corregidos; lint final vacío |
| Publicación de puertos en todas las interfaces | `docker ps` mostró 0.0.0.0/[::] pese a la opción loopback de red. [Bindings reales](phase02/evidence/local-containers.txt). Peticiones solo a 127.0.0.1; se apagó este stack. No se afirma listener limitado a localhost. Runner avisa y apaga lo que arranca salvo petición explícita de mantenerlo |
| URLs firmadas | TTL recomendado 60 s no es límite enforceable por estas RLS. Una URL emitida sigue viva hasta su expiración; test real muestra ventana de 3 s. Descarga autenticada preferida; documentado en [Storage](../15_STORAGE_SECURITY.md) |
| Borrado físico de blobs | Cola preparada y trigger verificado. Trabajador todavía NOT_VERIFIED/no implementado; necesario antes de distribución junto a eliminación de cuenta completa |
| Realtime/CDN/remoto | NOT_VERIFIED. SQL de publicación verificado; no cliente WebSocket/reconexión ni comportamiento de caché remota probado |
| Mobile/tiendas | Login Flutter, UI CRUD y demás fases NOT_RUN. No nuevo build APK necesario al no cambiar código móvil; se conserva evidencia de Fase 01. iOS NOT_RUN sin macOS/Xcode |
| Cuotas/moderación | Límites mínimos y denuncia/bloqueo de servidor implementados; no sustituyen moderación operativa, políticas legales ni auditoría de abuso previa a distribución |

- **Archivos de documentación actualizados:** README raíz/backend, PROGRESS,
  modelo conceptual enlazado al esquema definitivo, decisiones ADR-016,
  documentación Storage, informe y evidencias independientes de Fase 01.
- **Decisiones nuevas/ADR:** [ADR-016](../adr/016_DATABASE_SECURITY.md),
  [esquema definitivo](../14_DATABASE_IMPLEMENTATION.md) y
  [Storage](../15_STORAGE_SECURITY.md): atomicidad, versiones, idempotencia,
  normalización canónica, grants, cleanup privado y límites reales de Realtime/TTL.
- **Pendientes para la siguiente fase:** solo tras autorización de Fase 03,
  implementar Auth/perfil Flutter reales utilizando el esquema validado y
  mensajes de error locales. Mantener selección de ingredientes efímera y cuatro
  módulos. La conexión a un backend remoto o cambios remotos exigen autorización
  específica; no se ha enlazado ningún proyecto. Worker de fotos, flujo completo
  de eliminación de cuenta y pruebas Realtime/CDN deben cerrarse antes de publicar.
- **¿Autorizada siguiente fase?:** **NO**. Se detiene para revisión. El HEAD
  permanece `c5c80a158610752bfa48838edf1ca896fec5b82d`; cambios de Fase 02 quedan
  locales, sin commit/push, deploy ni modificaciones de Supabase remoto.

Instrucciones reproducibles completas: [supabase/README.md](../../supabase/README.md).
El runner valida project_id, acepta reset local solo con `-ResetLocal`, registra
evidencias y puede ejecutar backend solo con `-BackendOnly`. Configuración y
scripts nunca seleccionan un host remoto para las pruebas A/B/C.

## Autorización posterior de GitHub

El 2026-10-13, después del cierre descrito en este informe, el propietario
autorizó el commit y push del estado actual a `sergineko/MixTick`, rama `main`.
La afirmación anterior sobre HEAD y cambios locales describe el momento de
cierre, previo a esta autorización. No se autoriza Fase 03 ni despliegue.
