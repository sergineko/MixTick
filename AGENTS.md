# Reglas de implementación para cualquier asistente (AGENTS.md)

- Contenido de negocio **solo** en los cuatro módulos especificados; autenticación/perfil/ajustes son transversales.
- Nombre comercial de trabajo: MixTick (disponibilidad legal pendiente). **Identificador técnico APROBADO E INVARIABLE para este proyecto:** `es.sergiotech.mixtick` en Android `applicationId`, `namespace` e iOS `PRODUCT_BUNDLE_IDENTIFIER`; organización `es.sergiotech`; nombre Flutter en `pubspec.yaml`: `mixtick`. Nunca `com.example.*`, `com.mixtick.*` ni `recipe_social_app` como nombre de paquete. El nombre comercial puede cambiar sin cambiar este identificador.
- Implementar Flutter/Dart, Riverpod, GoRouter, Supabase Auth/Postgres/Storage/Realtime. Antes de fijar versiones, comprobar compatibilidad con la versión Flutter estable instalada y documentación oficial actual.
- Organización por funcionalidades, no por capas globales; separar UI, estado y repositorios, con modelos tipados.
- Servidor es autoridad para permisos. Habilitar RLS y probarla con usuarios reales de pruebas; no usar service_role en cliente.
- Recetas nuevas privadas por defecto. No revelar recetas privadas ni sus relaciones a terceros. La foto debe seguir la privacidad de la receta.
- La consulta de ingredientes es efímera: NO es despensa ni inventario; se comprueba presencia, NO cantidades disponibles.
- Compartir compra exige invitación explícita y aceptación; propietario gestiona miembros.
- Mantener reproducibilidad: migraciones, seeds, tests, datos de prueba controlados, informes.
- No afirmar que algo funciona sin prueba, no inventar capturas/resultados. Un comando no disponible = NOT_RUN y motivo.
- No deploys, commits, push, compras ni cambios remotos irreversibles sin autorización.
- Mantener accesibilidad, traducciones futuras y mensajes comprensibles. Español como primer idioma, cadenas localizables.
- Seguridad de contenido generado por usuarios: reportar, bloquear, moderación mínima y eliminación de cuenta antes de distribución pública.

- Para crear el proyecto Flutter: `flutter create --org es.sergiotech --project-name mixtick --platforms=android,ios .` en la raíz extraída. Verificar los archivos generados y corregir discrepancias **antes** de implementar más funciones.
- Antes de declarar completa la fase 01, ejecutar `python scripts/check_identifiers.py --strict` (o `py -3 scripts/check_identifiers.py --strict` en Windows), junto con pruebas Flutter; si falta Python, contrastar manualmente según `docs/13_PACKAGE_IDENTIFIERS.md`.
