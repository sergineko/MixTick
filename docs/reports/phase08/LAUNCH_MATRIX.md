# Matriz de preparación de lanzamiento — Fase 08

Fecha: 2026-10-14. Esta matriz separa evidencia local de preparación y ejecución
remota. Todos los componentes remotos necesitan autorización específica; no se
ha creado/configurado un proyecto remoto por analogía con Docker.

| Requisito | Estado local | Remoto/distribución | Preparación o configuración pendiente | Requiere autorización | Bloquea lanzamiento |
|---|---|---|---|---|---|
| Proyecto Supabase | PASS | NOT_RUN | Región, plan, acceso, TLS, propietarios y entorno de pruebas | Sí | Sí |
| Migraciones 001–015 | PASS | NOT_RUN | Backup previo, ejecución ordenada y verificación posterior | Sí | Sí |
| RLS/RPC/roles | PASS | NOT_VERIFIED | Repetir A/B/C sin credenciales servidor en clientes | Sí | Sí |
| Auth correo/confirmación | PASS | NOT_VERIFIED | SMTP real, redirect allowlist exacta, límites, entregabilidad | Sí | Sí |
| Recuperación/PKCE | PASS | NOT_VERIFIED | Android/iOS y correo externo en entorno autorizado | Sí | Sí |
| Storage privado | PASS | NOT_VERIFIED | Buckets/policies, límites y CORS reales | Sí | Sí |
| CDN/caché | NOT_RUN | NOT_VERIFIED | Expiración, privatización, borrado de objeto y acceso a URL conocida | Sí | Sí |
| Realtime | PASS | NOT_VERIFIED | Publicación, RLS, cargas/reconexión y revocación en servicio real | Sí | Sí |
| Worker físico | PASS | NOT_RUN | Desplegar Edge, secreto/Vault, cron, alertas, deadletters y recuperación | Sí | Sí |
| Eliminación de cuenta | PASS | NOT_RUN | Ciclo completo real, retención/backups y recurso web de eliminación | Sí | Sí |
| Moderación técnica | PASS | NOT_RUN | Asignación de operadores y secretos usuario controlados | Sí | Sí |
| Moderación humana/soporte | NOT_VERIFIED | NOT_VERIFIED | Responsables, turnos, contacto, normas y revisión de decisiones | Sí, para cambios externos | Sí |
| Copias/restore | NOT_RUN | NOT_VERIFIED | Política finita, restauración de ensayo y eliminación de datos restaurados | Sí | Sí |
| Métricas/alertas | NOT_RUN | NOT_RUN | Fallos/latencia/edad de cola/dead, logs minimizados y acceso | Sí | Sí |
| Límites/costes | NOT_VERIFIED | NOT_VERIFIED | Plan, presupuesto, alertas y pruebas de carga autorizadas | Sí | Sí |
| Android debug | PASS | NOT_RUN | APK local validado; no distribución | Publicación sí | Sí para distribución |
| Android release unsigned local | PASS | NOT_RUN | Firma real, bundle y dispositivo físico; build local no distribuible | Sí para firma/publicación | Sí |
| iOS | NOT_RUN | NOT_RUN | macOS/Xcode, signing, build y dispositivos compatibles; revisar ATS local | Sí para firma/publicación | Sí |
| Identificadores | PASS | NOT_VERIFIED | Revalidar artefactos de distribución, registro de apps y callbacks | Sí para cuentas externas | Sí |
| Marca/iconos | NOT_VERIFIED | NOT_VERIFIED | MixTick provisional, disponibilidad legal, iconos adaptativos/finales | Sí para compras/servicios | Sí |
| Versión/firma | NOT_VERIFIED | NOT_RUN | 0.1.0+1 de trabajo; decidir versión, protección de claves y recuperación | Sí | Sí |
| Privacidad/Data Safety | NOT_VERIFIED | NOT_RUN | Documento público, tratamiento real, UGC, retención, backups y proveedores | Sí para publicación | Sí |
| URL web de eliminación | NOT_RUN | NOT_RUN | Recurso público funcional sin redescargar app; URL de ficha Play | Sí | Sí |
| Accesibilidad | PASS | NOT_VERIFIED | Checks locales y capturas; lector de pantalla/dispositivos/iOS pendientes | No para QA local | Sí para validación objetivo |
| Rendimiento | PASS | NOT_VERIFIED | SQL/HTTP local; perfil físico, red móvil y volúmenes reales pendientes | Sí si infraestructura externa | Sí |

No existe evidencia suficiente para RELEASE READY. LOCAL READY se evalúa
independientemente en el informe: no supone que una build sin configuración o
sin firma sea distribuible. Ninguna fila pendiente se transforma en PASS por
haber preparado código o instrucciones.

Referencias de distribución consultadas:
[eliminación Google Play](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN),
[eliminación Apple](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/),
[UGC y revisión Apple](https://developer.apple.com/app-store/review/guidelines/).
Faltan la validación real en las consolas y las decisiones del propietario;
no se presenta esta matriz como asesoramiento o certificación legal.
