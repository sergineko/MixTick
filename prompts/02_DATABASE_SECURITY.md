# FASE 02 — Database Security

Lee `prompts/00_MASTER.md` y los documentos del paquete antes de comenzar. Inspecciona estado real del proyecto. **Implementa solo esta fase y detente al terminar.**


Objetivo: esquema Supabase completo y políticas de seguridad verificadas antes de implementar pantallas.

- Lee `docs/04_DATA_MODEL.md`, `docs/05_SECURITY_PRIVACY.md` y `docs/07_SHOPPING_REALTIME.md`.
- Migraciones versionadas para TODAS las tablas y sus CHECK, FK, índices, defaults, triggers timestamps, RLS, grants mínimos, funciones transaccionales indispensables.
- Privacidad `recipes.visibility='private'` por defecto. RLS de ingredientes y pasos de recetas igual al recurso padre; guardados/likes/comentarios solo visibles según autorización.
- Reglas de invitaciones, owner/member, aceptación segura y RPC atómica; cerrar search_path y permisos de SECURITY DEFINER.
- Catálogo inicial de ingredientes habituales en español y alias; permitir texto libre validado sin crear un catálogo contaminado.
- Storage privado con política acorde a autor/visibilidad (documentar límites de URLs firmadas, TTL corto).
- Diseñar idempotencia de importación con source_key o tabla transaccional adicional justificada.
- Crear pruebas negativas y positivas SQL con usuarios A/B/C; comprobar permisos mediante API no privilegiada, no solo ejecutar SQL como admin.
- Dejar scripts reproducibles para `supabase db reset` y ejecución de tests. No desplegar sin autorización.
- No hacer interfaces CRUD todavía.


## Salida obligatoria

Informe basado en `templates/PHASE_REPORT.md`: archivos, migraciones, evidencias de pruebas con comandos y resultados exactos, riesgos, cambios de documentación, pendientes. Sin commit/push/deploy.
