# MixTick

Base Flutter Android/iOS de la Fase 01 y backend SQL local de la Fase 02. Nombre técnico `mixtick`, organización
`es.sergiotech` e identificador fijo `es.sergiotech.mixtick` para ambas plataformas.
El nombre comercial MixTick sigue pendiente de validación legal/comercial.

La base incluye Riverpod, GoRouter, configuración opcional de Supabase, cuatro
pestañas protegidas, perfil como soporte, temas claro/oscuro y español `es_ES`.
Las pantallas de los módulos indican «Próximamente». No hay CRUD, datos de
negocio en la app ni login ficticio. Hay esquema SQL probado localmente, sin backend remoto provisionado. El acceso real se implementará
en su fase autorizada.

## Entorno

- Flutter estable 3.47.7 y Dart 3.13.5.
- Instalación autorizada: `C:\Users\Sergio\develop\flutter`.
- `C:\Users\Sergio\develop\flutter\bin` añadido al PATH de usuario. Abre una
  terminal nueva para que los comandos estén disponibles; las aplicaciones
  abiertas antes de la instalación pueden necesitar reiniciarse.
- Android Studio y Android SDK ya estaban disponibles. El diagnóstico aún
  indica algunas licencias pendientes; no impidieron generar el APK debug.
- Compilar, firmar y ejecutar iOS requiere macOS y Xcode; no se ha probado en Windows.
- Visual Studio no está instalado y solo afecta a Windows desktop, fuera de este proyecto.

Dependencias fijadas: `flutter_riverpod 3.4.3`, `go_router 18.0.2` y
`supabase_flutter 2.18.3`. Se verificaron los requisitos oficiales de SDK antes
de fijarlas; `pubspec.lock` conserva la resolución reproducible.

## Arranque y verificaciones

Desde la raíz del proyecto en una terminal nueva:

```powershell
flutter --version
dart --version
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
python scripts/check_identifiers.py --strict
flutter build apk --debug
flutter run -d <identificador-del-dispositivo-android>
```

`py -3 scripts/check_identifiers.py --strict` es una alternativa si el lanzador
Python funciona. En esta máquina los accesos WindowsApps `python` y `py` no
funcionaban; se utilizó el Python 3.12.14 incluido en el runtime de Codex:

```powershell
& 'C:\Users\Sergio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' scripts/check_identifiers.py --strict
```

Verificación completa con evidencias de cada comando y códigos de salida:

```powershell
.\scripts\verify_foundation.ps1 -PythonExecutable 'C:\Users\Sergio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -IncludeAndroidBuild
```

Se pueden pasar `-FlutterExecutable` y `-DartExecutable` con rutas absolutas si
el proceso actual todavía no tiene el PATH nuevo. La salida está en
`docs/reports/evidence/`; `results.json` registra la última ejecución.

El APK de depuración se genera en `build/app/outputs/flutter-apk/app-debug.apk`.
No constituye una distribución publicada ni una prueba en un teléfono.

## Supabase

La app arranca sin credenciales y mantiene las rutas protegidas en la pantalla
de acceso. No contacta con Supabase si no está configurado. Para configurar un
proyecto existente en una fase posterior:

1. Copia `config/supabase.example.json` a `config/supabase.local.json`.
2. Introduce una URL HTTPS y una clave pública publishable del proyecto.
3. Ejecuta `flutter run --dart-define-from-file=config/supabase.local.json`.

También se admiten `--dart-define=SUPABASE_URL=...` y
`--dart-define=SUPABASE_PUBLISHABLE_KEY=...`. Un proyecto heredado puede usar su
JWT público `anon` en la segunda variable. No se permiten claves secret ni
JWT de rol administrativo. Las variables del cliente se pueden extraer del
binario: solo deben contener configuración pública.

La validación local es sintáctica; inicializar el SDK no verifica una conexión
ni sustituye las políticas del servidor. En Fase 01 no se implementa inicio de
sesión, registro, recuperación ni consultas a tablas. RLS y Storage se han probado en Fase 02 con Auth, PostgREST y Storage locales y
cuentas reales A/B/C. Realtime tiene configuración SQL preparada; clientes y
reconexión quedan pendientes. Ver [backend](supabase/README.md) para reproducir
las migraciones y pruebas sin modificar Supabase remoto.

## Estructura

```text
lib/
  app/             Aplicación, router, shell, tema y localización ARB
  core/            Configuración, bootstrap, errores y estados de UI
  features/
    auth/          Repositorio de observación de sesión y acceso mínimo
    profile/       Ruta transversal de perfil
    community/     Comunidad
    recipes/       Mi recetario
    cook_today/    ¿Qué cocino hoy?
    shopping/      Lista de compra
  shared/          Modelos y widgets compartidos
supabase/          Seis migraciones, catálogo, RLS, Storage privado y tests reales
assets/            Imágenes e iconos futuros
integration_test/  Pendiente de flujos reales y entorno de dispositivo
scripts/           Verificador de identificadores y checks de Foundation
```

Cada funcionalidad reserva `data/`, `domain/` y `presentation/`. Los directorios
sin implementación usan `.gitkeep`. Las pantallas pasan por proveedores y
repositorios; no acceden directamente al cliente Supabase.

`flutter gen-l10n` genera Dart desde `lib/app/localization/app_es.arb`, con
`app_es_ES.arb` como variante regional que hereda los textos base. Para futuras
traducciones se añadirán recursos ARB; no se editará el código generado.

Los renders de widget se pueden reproducir con:

```powershell
flutter test --reporter expanded --dart-define=CAPTURE_FOUNDATION_PREVIEWS=true
```

Se escriben en `docs/reports/previews/`, cargando las fuentes del SDK. Muestran
widgets renderizados en pruebas y sesiones controladas exclusivamente en tests;
no son capturas de dispositivos ni conexiones externas.

## Estado y siguientes pasos

Consulta `docs/PROGRESS.md`, `docs/reports/PHASE_01_REPORT.md`,
`docs/reports/PHASE_02_REPORT.md` y `docs/adr/` para resultados y limitaciones.

Las Fases 01 y 02 están implementadas. La Fase 03 requiere revisión y autorización
expresa del propietario.
El propietario autorizó el commit y push del estado de Fase 01
a [sergineko/MixTick](https://github.com/sergineko/MixTick) y, posteriormente,
el commit y push del estado actual de Fase 02 el 2026-10-13. No hay autorización
de despliegue ni de Fase 03. Los informes conservan el estado histórico al
finalizar cada implementación, previo a su autorización de GitHub.
Los documentos, manifiesto y checksums del paquete original se conservan como
referencia; los checksums originales no describen el proyecto modificado.
