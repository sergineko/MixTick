# INSTRUCCIONES PARA EL PROPIETARIO — Iniciar MixTick con una IA de programación

## Qué recibes

Este ZIP contiene **especificaciones, decisiones, prompts y herramientas de verificación**. No contiene todavía un proyecto Flutter compilable, cuentas Supabase, claves privadas, imágenes comerciales ni una app publicada. La IA de programación debe generar esos elementos por fases y probarlos.

**Identificadores:** Android `es.sergiotech.mixtick`, iOS `es.sergiotech.mixtick`, nombre Flutter `mixtick`.

## Inicio recomendado en Windows con VS Code o editor con IA

1. Instala/configura **Flutter SDK + Dart**, Android Studio/Android SDK y un editor con asistencia de IA capaz de modificar archivos del proyecto. Comprueba que `flutter --version` y `flutter doctor` funcionan en una terminal. Instala Git si tu herramienta lo necesita. La disponibilidad de macOS/Xcode será necesaria más adelante para compilar y firmar iOS.
2. Crea una carpeta de trabajo, por ejemplo `C:\Proyectos\MixTick`, y **extrae el contenido interior del ZIP en ella** (los archivos `AGENTS.md`, `AI_START_HERE.md`, `prompts/` y `docs/` deben quedar en la raíz; no en una subcarpeta extra).
3. Abre exactamente esa carpeta con tu editor. Si tu IA trabaja sobre el árbol de archivos, tendrá acceso a las instrucciones. Si solo acepta archivos adjuntos, adjunta el ZIP y el archivo `PROMPT_DE_ARRANQUE.md` e indícale que primero inspeccione el contenido.
4. Copia el texto completo de `PROMPT_DE_ARRANQUE.md` como **primer mensaje** de la IA. No hay que pegar a la vez las ocho fases.
5. La IA debe leer las especificaciones y **ejecutar solo la FASE 01** (`prompts/01_FOUNDATION.md`). Verifica que usa `flutter create --org es.sergiotech --project-name mixtick --platforms=android,ios .`, genera correctamente Android/iOS y no finge una conexión Supabase si todavía no proporcionaste un proyecto.
6. Al acabar, exige reporte según `templates/PHASE_REPORT.md` y pruebas concretas: `flutter analyze`, `flutter test`, y `py -3 scripts/check_identifiers.py --strict` o `python scripts/check_identifiers.py --strict`.
7. Si el reporte es satisfactorio, da una autorización nueva para `prompts/02_DATABASE_SECURITY.md`. Continúa así, **de una en una**, hasta `prompts/08_RELEASE_AUDIT.md`.

## Texto que enviarás al aprobar cada fase

> He revisado el informe de la fase actual. Si no hay errores bloqueantes, ejecuta únicamente la siguiente fase del directorio `prompts/`. Lee de nuevo `AGENTS.md`, las decisiones, el documento correspondiente, ejecuta las pruebas necesarias y detente con un informe de evidencias. No hagas commit, push ni despliegues sin permiso.

## Cómo resolver dependencias externas

- En la fase de base de datos/auth puede hacer falta crear un proyecto Supabase y configurar su URL y su clave **publicable** o anon según versión. La IA debe explicarte la configuración precisa y **no inventar credenciales** ni pedirte claves `service_role` en el móvil.
- Las operaciones remotas y despliegues requieren tu aprobación. El proyecto debe funcionar con configuraciones seguras y sin datos personales de prueba comprometidos.
- Para probar las cuentas reales, el email y la confirmación deben configurarse en Supabase. La IA señalará qué pruebas están bloqueadas por falta de ese entorno.

## Entregables esperados por fase

- Código real (cuando corresponda), documentación actualizada, pruebas ejecutadas con evidencia y lista de pendientes.
- Un reporte `PASS`, `FAIL`, `BLOCKED` o `NOT_RUN` para cada verificación obligatoria, con motivo si falta entorno.
- Ningún salto automático de fase. Tú autorizas el siguiente paso.

## Control esencial

Antes de avanzar más allá de la Fase 01 confirma:

- `pubspec.yaml` declara `mixtick`.
- Android contiene `applicationId = "es.sergiotech.mixtick"` y `namespace = "es.sergiotech.mixtick"` (o sintaxis Gradle equivalente).
- iOS Runner tiene `PRODUCT_BUNDLE_IDENTIFIER = es.sergiotech.mixtick`.
- No hay referencias a `com.example` como identificadores de la app final.
- La IA informa de manera honesta lo que puede probar en tu PC Windows y lo que precisa macOS o Supabase.
