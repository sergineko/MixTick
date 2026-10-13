# FASE 01 — Foundation

Lee `prompts/00_MASTER.md` y los documentos del paquete antes de comenzar. Inspecciona estado real del proyecto. **Implementa solo esta fase y detente al terminar.**


Objetivo: crear proyecto Flutter Android/iOS compilable y arquitectura, sin lógica de negocio simulada.

- Verificar herramientas disponibles (`flutter doctor`, `flutter --version`) y compatibilidad de paquetes estables.
- En la raíz del repositorio extraído, si aún no hay proyecto Flutter, crear exactamente con `flutter create --org es.sergiotech --project-name mixtick --platforms=android,ios .` (ajustar solo si la CLI exige una sintaxis equivalente). Nombre del paquete Flutter `mixtick` en pubspec.yaml.
- Validar Android `applicationId`, `namespace` y paquete `MainActivity`: `es.sergiotech.mixtick`. Validar iOS `PRODUCT_BUNDLE_IDENTIFIER`: `es.sergiotech.mixtick` en las configuraciones que apliquen; **no** `com.example.*`.
- Ejecutar `py -3 scripts/check_identifiers.py --strict` o `python scripts/check_identifiers.py --strict` y comunicar su resultado.
- Crear estructura indicada en `docs/03_TECH_ARCHITECTURE.md`.
- Inicializar Riverpod, GoRouter y configuración segura de Supabase mediante variables públicas de entorno. Si el backend no está provisionado, indicar configuración pendiente, sin inventar conexión.
- Implementar cuatro pestañas fijas, icono perfil, rutas protegidas y pantalla de acceso mínima navegable; no hacer implementaciones falsas de login.
- Diseño base consistente claro/oscuro, textos localizables es-ES, estados empty/loading/error reutilizables.
- Crear/actualizar docs/PROGRESS.md, ADRs y README real del repositorio.
- Comprobaciones: `dart format`, `flutter analyze`, `flutter test`, verificador de IDs, widget test de cuatro pestañas y protección de rutas cuando sea posible.
- NO crear todavía backend ni módulos CRUD.


## Salida obligatoria

Informe basado en `templates/PHASE_REPORT.md`: archivos, migraciones, evidencias de pruebas con comandos y resultados exactos, riesgos, cambios de documentación, pendientes. Sin commit/push/deploy.
