# PROGRESS — MixTick

| Fase | Estado (TODO/IN_PROGRESS/VERIFIED/BLOCKED) | Fecha | Pruebas verificadas | Bloqueos |
|---|---|---|---|---|
| 01 Base | VERIFIED | 2026-10-13 | Analyze sin incidencias; 21 tests; formato; IDs estrictos; APK debug Android e identidad del binario | iOS y ejecución en dispositivos NOT_RUN; Supabase real pendiente, previsto fuera de esta fase |
| 02 BD y permisos | VERIFIED | 2026-10-13 | 6 migraciones desde cero; 19 checks pgTAP; 20 escenarios reales Auth/API/Storage; lint limpio; analyze, 21 tests Flutter y IDs estrictos | Entorno remoto y clientes Realtime NOT_VERIFIED; trabajador de limpieza pendiente |
| 03 Auth/Perfil | TODO | — | — | No autorizada |
| 04 Mi recetario | TODO | — | — | No autorizada |
| 05 Comunidad | TODO | — | — | No autorizada |
| 06 ¿Qué cocino? | TODO | — | — | No autorizada |
| 07 Compra | TODO | — | — | No autorizada |
| 08 Auditoría | TODO | — | — | No autorizada |

## Último cambio

Fecha: 2026-10-13 (Europe/Madrid).
Motivo: cierre local de `prompts/02_DATABASE_SECURITY.md`, con Foundation intacta.
Decisiones: [ADR-016](adr/016_DATABASE_SECURITY.md).
Evidencias e informe: [Fase 02](reports/PHASE_02_REPORT.md); [Fase 01 histórica](reports/PHASE_01_REPORT.md).
Próximo paso autorizado: commit y push del estado actual a GitHub por petición
posterior del propietario. No avanzar a Fase 03 ni desplegar.

`VERIFIED` se limita a las comprobaciones locales enumeradas. No representa una
verificación de login Flutter, backend remoto, CDN, cliente Realtime, compilación
iOS o publicación. RLS/Storage sí tienen evidencia real en Supabase local (Fase 02).
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
