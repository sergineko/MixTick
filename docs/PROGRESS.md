# PROGRESS — MixTick

| Fase | Estado (TODO/IN_PROGRESS/VERIFIED/BLOCKED) | Fecha | Pruebas verificadas | Bloqueos |
|---|---|---|---|---|
| 01 Base | VERIFIED | 2026-10-13 | Analyze sin incidencias; 21 tests; formato; IDs estrictos; APK debug Android e identidad del binario | iOS y ejecución en dispositivos NOT_RUN; Supabase real pendiente, previsto fuera de esta fase |
| 02 BD y permisos | VERIFIED | 2026-10-13 | 6 migraciones desde cero; 19 checks pgTAP; 20 escenarios reales Auth/API/Storage; lint limpio; analyze, 21 tests Flutter y IDs estrictos | Entorno remoto y clientes Realtime NOT_VERIFIED; trabajador de limpieza pendiente |
| 03 Auth/Perfil | VERIFIED | 2026-10-13 | 7 migraciones desde cero; 25 pgTAP; 20 regresiones API; 13 escenarios cliente por cada modo de correo; 48 tests Flutter; 2 procesos Android reales; analyze/formato/IDs/APK; aislamiento real | iOS y galería interactiva NOT_RUN; remoto/CDN/Realtime/worker NOT_VERIFIED |
| 04 Mi recetario | TODO | — | — | No autorizada |
| 05 Comunidad | TODO | — | — | No autorizada |
| 06 ¿Qué cocino? | TODO | — | — | No autorizada |
| 07 Compra | TODO | — | — | No autorizada |
| 08 Auditoría | TODO | — | — | No autorizada |

## Último cambio

Fecha: 2026-10-13 (Europe/Madrid).
Motivo: cierre local de `prompts/03_AUTH_PROFILE.md`, con fases anteriores aceptadas.
Decisiones: [ADR-017](adr/017_AUTH_PROFILE.md).
Informe completo/evidencias: [Fase 03](reports/PHASE_03_REPORT.md).
Contratos: [Auth/perfiles](16_AUTH_PROFILE.md). Informes anteriores:
[Fase 02](reports/PHASE_02_REPORT.md) y [Fase 01](reports/PHASE_01_REPORT.md).
Próximo paso autorizado: ninguno; esperar revisión del propietario. Sin commits,
push, deploy, proyectos Supabase remotos ni Fase 04.

`VERIFIED` se limita a las comprobaciones locales enumeradas. No representa una
verificación de backend remoto, CDN, cliente Realtime, compilación iOS o
publicación. Auth/perfiles Flutter y RLS/Storage se comprueban localmente en
Fase 03, incluyendo restauración entre procesos y callback ACTION_VIEW Android.
La implementación de la Fase 01 finalizó sin commits, push, despliegues ni
cambios de backend remoto.

## Autorización posterior de GitHub

Fecha: 2026-10-13 (Europe/Madrid).
El propietario ha autorizado crear el commit inicial y subir el proyecto a
`https://github.com/sergineko/MixTick.git`, rama `main`.
El alcance incluye código, documentación, pruebas y evidencias; se excluyen
cachés, configuración local y artefactos de compilación según `.gitignore`.
Esta primera autorización de GitHub se limitó al estado de Fase 01. Se verificó
el push `c5c80a158610752bfa48838edf1ca896fec5b82d`.

## Autorización de Fase 02

Fecha: 2026-10-13. Implementar esquema, seguridad y pruebas locales conservando
Foundation. No cambiar interfaces funcionales, realizar commits/push, desplegar,
modificar Supabase remoto ni avanzar a Fase 03.

Fase 02 finalizada con 16 tablas públicas y 3 privadas, 50 ingredientes y 74
entradas de alias. A/B/C y archivos de pruebas fueron retirados; auditoría final
confirma cero cuentas, recetas, listas, fotos y ledger de fixtures. Se apagó solo
`mixtick-phase02` y no quedaron sus puertos publicados. La CLI había enlazado
puertos a todas las interfaces; incidencia y límites constan en el informe.
No se hicieron commits/push nuevos ni modificaciones remotas de Supabase.

## Autorización posterior de GitHub para Fase 02

Fecha: 2026-10-13 (Europe/Madrid).
Tras el informe de cierre, el propietario solicitó «Realiza push del estado
actual a github». Autoriza crear el commit de estos cambios y subirlo a
`https://github.com/sergineko/MixTick.git`, rama `main`. Se incluyen migraciones,
pruebas, documentación y evidencias; se excluyen secretos, configuración local,
cachés y binarios según `.gitignore`. Se mantiene el cierre de Fase 02 sin
autorizar Fase 03, despliegues ni modificaciones de Supabase remoto.

## Autorización de Fase 03

Fecha: 2026-10-13. El propietario acepta Fases 01/02 y autoriza únicamente
autenticación y perfiles reales. Conserva los identificadores, las seis
migraciones históricas y las cuatro pestañas. Autoriza pruebas locales con
aislamiento efectivo; prohíbe commits/push, despliegues, Supabase remoto y
avance a Fase 04. La autorización de push previa correspondió a Fase 02;
HEAD al inicio de esta fase: `143158444c1a3f15c0914862e93780401b857f59`.

Fase 03 cerrada con Auth/perfil/avatar implementados y verificados localmente.
Todas las suites finales enumeradas están PASS; se preservan FAIL iniciales y
los límites por plataforma. Se retiraron cuentas/archivos/correos de fixtures;
auditoría final confirma cero usuarios, perfiles, recetas, listas, fotos, jobs
y ledger de pruebas. Solo permanecen el catálogo y los esquemas reproducibles.
`mixtick-phase02` apagado sin puertos publicados. Las seis migraciones históricas,
los módulos de negocio y los informes/evidencias aceptados permanecen intactos.
HEAD sigue siendo `143158444c1a3f15c0914862e93780401b857f59`; cambios de Fase 03
locales sin commit/push. Fase 04 no autorizada.

## Autorización posterior de GitHub para Fase 03

Fecha: 2026-10-13 (Europe/Madrid).
Tras el cierre de Fase 03, el propietario solicitó «Realiza push del estado
actual del proyecto». Autoriza crear el commit del estado actual y subirlo a
`https://github.com/sergineko/MixTick.git`, rama `main`. Se incluyen código,
migración, pruebas, documentación y evidencias verificables de Fase 03; se
excluyen secretos, configuración local, cachés y binarios según `.gitignore`.
La prohibición de Git durante la implementación queda sustituida por esta
autorización posterior. Se mantiene el cierre sin avanzar a Fase 04, desplegar
ni modificar Supabase remoto. El resultado del push se verifica comparando el
commit local con `refs/heads/main` del repositorio remoto.
