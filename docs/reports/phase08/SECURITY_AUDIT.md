# Auditoría de seguridad Fase 08

Entorno: Supabase CLI 2.120.0, Docker local aislado, API 127.0.0.1:54321,
GoTrue real, PostgreSQL/RLS, Storage de archivos y Realtime reales. Fecha:
2026-10-14. Ninguna prueba demuestra configuración remota. Las claves servidor
solo se usan en funciones Edge o preparación/limpieza del host identificadas;
esas intervenciones no cuentan como pruebas de permisos del producto.

Los resultados remiten a [regresiones](evidence/backend-regression-results.json),
[108 SQL](evidence/sql-tests.txt), [API A/B/C](evidence/api-regression.txt),
[operaciones](evidence/operations-operator-cli-final/results.json) y
[E2E real](evidence/e2e-performance-final.txt). Las suites de 01–07 y sus afirmaciones se
preservan. Los casos híbridos conservan su clasificación: una respuesta retenida
por un transporte controlado después de una operación real no es una caída de
red espontánea ni un segundo teléfono.

| Área requerida | Estado local | Evidencia y límite |
|---|---|---|
| 1. RLS de tablas | PASS | SQL y API de 16 tablas públicas; nuevas privadas sin grants ordinarios; cuenta activa restrictiva AND |
| 2. Grants SQL/RPC | PASS | SQL007: worker/acciones administrativas solo servidor; usuarios ordinarios reciben 403; moderación verifica operador |
| 3. Schemas | PASS | `private` fuera de la exposición API; las proyecciones públicas no dan acceso a sus tablas |
| 4. Invoker/definer | PASS | Matching, feed y wrappers invoker; definers mínimos revisados con identidad Auth y autorización explícita |
| 5. search_path | PASS | Vacío en definers propios; referencias calificadas; lint SQL sin incidencias |
| 6. Storage | PASS | Dos buckets privados, ruta y owner coordinados, active-reference DELETE guard; A/B/C UUID directos; F01–F12 |
| 7. Cambio de privacidad | PASS | Recetas/Comunidad/matching/API/E2E: relaciones, guardados y fotos no elevan acceso tras privatizar/borrar/bloquear |
| 8. Sesiones | PASS | Auth13 por modo y D03: refresh/getUser fallan tras borrar; JWT antiguo no obtiene datos ni recrea perfil |
| 9. Recuperación | PASS | Confirmación Mailpit y dos procesos Android con callback real; no correo externo |
| 10. Tokens | PASS | PKCE y namespace por backend; prueba nativa de almacenamiento cifrado sin JWT/JSON legibles; tokens nunca en evidencia |
| 11. Secretos Flutter | PASS | Configuración pública tipada rechaza rol administrativo; secretos Edge/host en entorno ignorado; escaneo final separado |
| 12. Perfiles | PASS | Sin correo en proyecciones; campos mínimos; bloqueo simétrico/moderación; avatar solo referencia permitida |
| 13. Bloqueos | PASS | API/Comunidad/matching/compra con cuentas reales; ambas direcciones de bloqueo permanecen autorizativas |
| 14. Guardados | PASS | Es referencia, no copia ni permiso extra; acceso desaparece si cambia privacidad/bloqueo |
| 15. Listas | PASS | Propiedad/membresía verificada en servidor; C conoce UUID y no lee ni escribe; productos aislados |
| 16. Invitaciones | PASS | Creación explícita, aceptación y dueño administra; invitación antigua no restaura acceso revocado/eliminado |
| 17. Realtime | PASS | Sockets A/B independientes, C/anon sin eventos; solo listas/items; sin eventos DELETE públicos con datos privados |
| 18. Idempotencia | PASS | Ledgers históricos + UUID de petición; operaciones repetidas/commit con respuesta perdida; claims stale no terminan trabajo ajeno |
| 19. Concurrencia | PASS | Versión esperada/PT409, un ganador E2E; SKIP LOCKED+lease; subida simultánea con borrado D13 |
| 20. Entrada | PASS | SQL constraints, límites, 4 KiB en Edge, campos permitidos, UUID/rutas estrictas, D02 spoofing/contraseña incorrecta |
| 21. Abuso | PASS | Cuotas existentes (recetas10/min, comentarios20/min, listas/invitaciones20/min, denuncias5/min), límites paginación y fotos; no garantía anti-DDoS |
| 22. Borrado | PASS | Retirada PostgreSQL, DELETE Storage físico y Auth real; caída real Storage/Auth recuperada; trazas minimizadas 30 días |
| 23. Aislamiento | PASS | API20 y regresiones A/B/C directas; worker conserva objeto B; D09 conserva cuenta/lista/receta ajena |
| 24. Respuestas tardías | PASS | UID antes/después de awaits; SessionScope; mocks de A→B + transportes híbridos identificados; avatar ambiguo conciliado |
| 25. Logs | PASS | Errores Edge con categoría fija, sin upstream body; salidas publicadas redacted; manifest/secretos solo ignorados |

PASS se limita a los escenarios enlazados. Pentest externo, revisión legal,
verificación CDN/backups, ataques volumétricos, auditoría de proveedores y
validación en plataformas remotas: NOT_VERIFIED. Certificación formal de
accesibilidad/seguridad: NOT_RUN.

## Análisis específico de privilegios

012 no convierte matching en definer ni crea cache privilegiada de recetas.
El conjunto simétrico de bloqueos procede exclusivamente del UID autenticado.
El helper privado devuelve UUIDs de bloqueos que afectan a ese mismo actor,
sin aceptar un UID arbitrario, sin datos Auth/razones y sin EXECUTE anon. Las
cabeceras y sus relaciones siguen evaluando RLS; tests negativos de relaciones,
bloqueos y guardados permanecen intactos. El cambio reduce autorización repetida
por ingrediente y permite semijoin/hash sobre recetas visibles.

013 reclama solo objetos de los buckets y propietarios revisados. Las rutas
manipuladas/owners cruzados terminan en categoría fija `dead`, sin DELETE. La
barrera de referencias permanece tras un fallo o caducidad de lease. No se da
por eliminado un objeto solo porque otro usuario ya no puede descargarlo.

014 impide el ataque de conservar un JWT válido para recrear perfil tras borrar
la identidad. Verificar `auth.uid()` solo no bastaría: la policy comprueba que la
cuenta existe y no está en retirada. Las funciones privilegiadas históricas
reutilizan helpers reforzados. La consulta de conciliación del borrado es una
excepción mínima: solo estado de su request/UID, incluso con el JWT anterior.

015 asigna operadores en tabla privada controlada, nunca por metadata mutable.
Los destinos provienen de denuncias existentes y las acciones quedan auditadas.
El operador no recibe contenido privado de recetas ni datos del denunciante.
La herramienta técnica está verificada localmente; dotación humana, contacto y
proceso de apelación siguen NOT_VERIFIED y bloquean distribución.

## Riesgos y controles pendientes

| Riesgo | Estado | Control necesario antes de lanzamiento |
|---|---|---|
| URLs/copies previamente descargadas | NOT_VERIFIED | RLS revoca acceso futuro; no recupera copias exportadas. Verificar CDN/cache remoto |
| Trabajos agotados | PASS | Visibles en cola dead, cinco intentos; recuperación F10. Operación remota/alertas pendientes |
| Retención de backups | NOT_VERIFIED | Plazos/restore y procedimiento de solicitudes de datos con proveedor real |
| Cuotas remotas/costes | NOT_VERIFIED | Rate limits del gateway/Auth/Storage, presupuesto y alertas; cuotas SQL no bastan contra tráfico distribuido |
| Secretos servidor | NOT_VERIFIED | Rotación, Vault/entorno y control de acceso remoto; ninguna clave real generada o usada aquí |
| Cuenta propietaria de compra | PASS | UI advierte y backend elimina su lista completa; las listas ajenas sobreviven |
| Reautenticación por contraseña | PASS | App actual usa correo/contraseña; otros proveedores no implementados ni declarados compatibles |
| Firma, dispositivos, iOS | NOT_RUN | Claves autorizadas, build/dispositivos reales y Xcode |

## Incidencias y decisión de revisión automática

La revisión automática rechazó retirar la protección DELETE de fotos activas por
el riesgo de referencias rotas. Esa retirada no se ejecutó. Se conservó la
protección y se adaptó únicamente la limpieza de fixtures del API histórico:
desvincula con el RPC versionado del propietario antes de borrar sus archivos.
Las 20 aserciones originales permanecen intactas. La alternativa segura pasó.

Los fallos iniciales y sus correcciones están conservados en evidencia; no se
reclasifican como pruebas que pasaron en su primera ejecución. Ver inventario de
incidencias en el informe de fase.
