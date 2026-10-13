# FASE 07 — Shopping Realtime

Lee `prompts/00_MASTER.md` y los documentos del paquete antes de comenzar. Inspecciona estado real del proyecto. **Implementa solo esta fase y detente al terminar.**


Implementar listas múltiples, CRUD ítems, marca comprada, propietario/miembros, invitaciones por username con aceptación explícita, revocación y permisos backend. Supabase Realtime con recarga tras desconexión. Integrar importación desde recetas accesibles y desde faltantes de ¿Qué cocino hoy? con previsualización/editable, idempotencia por request_id, operación atómica y sin revelar origen de recetas privadas. Mantener independiente texto libre y unidades, no sumar incompatibles, no cambiar comprados. Tests con usuarios A/B/C, reconexión, reintento, acceso revocado y concurrencia.


## Salida obligatoria

Informe basado en `templates/PHASE_REPORT.md`: archivos, migraciones, evidencias de pruebas con comandos y resultados exactos, riesgos, cambios de documentación, pendientes. Sin commit/push/deploy.
