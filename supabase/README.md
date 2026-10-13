# Backend MixTick — Fases 02–03

Esquema real de PostgreSQL/Supabase con 16 tablas públicas y 3 técnicas privadas,
RLS, catálogo español, Storage privado y RPC transaccionales. Fase 03 añade
solo la séptima migración para avatares de perfil. Las interfaces y
repositorios Flutter de negocio continúan pendientes de sus fases.

Consulta `docs/14_DATABASE_IMPLEMENTATION.md`, `docs/15_STORAGE_SECURITY.md` y
`docs/reports/PHASE_02_REPORT.md` para contratos, evidencia y límites.

## Entorno reproducible

- Docker Desktop existente, contenedores Linux.
- Supabase CLI 2.120.0, portátil en `.tooling/supabase/` e ignorada por Git.
- PostgreSQL 17.11 (imagen `supabase/postgres:17.11.0.004`).
- Proyecto local dedicado `mixtick-phase02`; API de pruebas `127.0.0.1:54321`.
- Python 3.11+ (el runner HTTP usa solo biblioteca estándar).
- Flutter 3.47.7 / Dart 3.13.5 para verificar Foundation.

Preparar la CLI en Windows, con checksum oficial fijado:

```powershell
.\scripts\install_supabase_cli.ps1
```

El script no cambia PATH ni instala un servidor Node. Docker debe estar ya
instalado y arrancado. Las imágenes oficiales se descargan al primer start.
No se configura Supabase remoto ni se requiere login/link/access token remoto.

## Ejecutar migraciones y todas las pruebas

Desde la raíz, con Docker arrancado y una terminal nueva:

```powershell
.\scripts\verify_database.ps1 -StartLocal -ResetLocal -PythonExecutable 'C:\Users\Sergio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -FlutterExecutable 'C:\Users\Sergio\develop\flutter\bin\flutter.bat' -DartExecutable 'C:\Users\Sergio\develop\flutter\bin\dart.bat'
```

`-ResetLocal` es optativo y borra los datos del proyecto local de pruebas
`mixtick-phase02` antes de aplicar migraciones y seed. No usarlo para conservar
trabajo local de desarrollo. Para comprobar el esquema ya aplicado, omitirlo.
`-BackendOnly` permite ejecutar únicamente SQL/lint/API. Python, Flutter y Dart
pueden pasarse como comandos del PATH cuando estén disponibles.

El runner valida el project_id, usa `--local` y la red exacta de ese proyecto.
Ejecuta pgTAP, lint SQL, escenarios A/B/C por API, analyze/test Flutter, formato
e IDs estrictos. Registra código de salida, fecha y PASS/FAIL/NOT_RUN en
`docs/reports/phase02/evidence/`. Avisos del lint se consideran FAIL aunque
la CLI devuelva 0. Las claves locales de setup se ocultan en las evidencias.

Si arranca el stack con `-StartLocal`, lo apaga al finalizar, conservando sus
volúmenes. `-KeepLocalRunning` permite mantenerlo para inspección explícita.
No se apaga Docker Desktop ni se modifican otros proyectos.

## Puertos: incidencia histórica y solución de Fase 03

Las peticiones de la suite se restringen a localhost y rechazan hosts remotos.
Se crea la red Docker con host_binding_ipv4=127.0.0.1, pero esta versión de la
CLI publicaba puertos en `0.0.0.0/[::]` a pesar de dicha opción en Fase 02.
Fase 03 incorpora `scripts/start_isolated_supabase.ps1`: adapta únicamente los
comandos Docker del proceso CLI e impone `127.0.0.1` antes de crear contenedores.
`scripts/assert_local_isolation.ps1` verifica bindings, listeners y conexiones
por otras interfaces. El runner anterior utiliza ahora estos helpers y rechaza
exposición. No ejecutar `supabase start` directo para estas pruebas.

No se cambian firewall ni configuración global de Docker. Al cierre de la Fase 02 se comprobó que
no quedaban contenedores ni puertos publicados de `mixtick-phase02`.

## Comandos manuales

La red debe existir y todas las operaciones locales deben recibir su ID completo:

```powershell
$networkId = docker network inspect mixtick-local-tests --format '{{.Id}}'
.\scripts\start_isolated_supabase.ps1
.\scripts\assert_local_isolation.ps1
.\.tooling\supabase\supabase.exe test db --network-id $networkId
.\.tooling\supabase\supabase.exe db lint --local --level warning --network-id $networkId
python scripts/test_database_api.py --cli .tooling/supabase/supabase.exe
.\.tooling\supabase\supabase.exe stop --project-id mixtick-phase02
```

Omitir la red en db reset/test db causó fallos reales de DNS/reinicio en esta
versión. No se usan stop --all ni --no-backup. La CLI start/status puede mostrar
claves administrativas de setup local: el runner las redacta; no copiarlas a
Flutter, Git ni documentación. La API de pruebas utiliza exclusivamente la
clave pública anon y JWT de usuarios reales creados por Auth.

## Datos de pruebas y límites de verificación

`seed.sql` no crea cuentas ni contenido; el catálogo inicial es una migración
versionada para conservar los mismos IDs en cualquier entorno compatible.
La suite crea A/B/C con direcciones ficticias example.test y credenciales
aleatorias, usa sus tokens reales y limpia solo sus cuentas/archivos al terminar.
La consulta SQL postgres se limita a estructura, cola y limpieza de fixtures.
No se usan claves administrativas para probar lecturas/escrituras de producto.

Auth local conserva auto-confirmación para fixtures. La Fase 03 implementa
login/registro/perfil reales y verifica también confirmación activada temporalmente
con Mailpit. No se prueba entrega de correo de producción. HTTP móvil se admite
solo con flag explícito y destinos locales en desarrollo; release exige HTTPS.
Para reset seguro y la batería completa usar `scripts/verify_auth_profile.ps1
-BackendChecks -ResetLocal -IncludeAndroidBuild`. Ver [Auth/perfiles](../docs/16_AUTH_PROFILE.md).

RLS, Storage y concurrencia API se han verificado localmente. Producción,
CDN/caché, clientes Realtime/reconexión y trabajador físico de limpieza de blobs
siguen pendientes. No se puede publicar la app basándose únicamente en esta fase.
