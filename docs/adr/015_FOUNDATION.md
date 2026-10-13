# ADR-015 — Base de MixTick (Fase 01)

Fecha: 2026-10-13. Estado: adoptada dentro del alcance autorizado de Foundation.

## Entorno y dependencias

No había proyecto ni SDK Flutter accesible. Tras la autorización expresa de
instalación del propietario se instaló Flutter estable 3.47.7 con Dart 3.13.5
en `C:\Users\Sergio\develop\flutter`, con PATH de usuario y SHA256 contrastado
con los metadatos oficiales. No se instaló un segundo SDK Dart independiente.

Se consultaron los requisitos de SDK en pub.dev antes de fijar versiones:

| Paquete | Versión | Dart mínimo | Flutter mínimo |
|---|---|---|---|
| flutter_riverpod | 3.4.3 | 3.12.0 | 3.0.0 |
| go_router | 18.0.2 | 3.12.0 | 3.44.0 |
| supabase_flutter | 2.18.3 | 3.9.0 | 3.35.0 |

`pubspec.lock` conserva la resolución. `flutter pub get` comprueba su
compatibilidad efectiva. No se añadieron generadores Riverpod ni GoRouter.

Fuentes consultadas: [archivo oficial de Flutter](https://docs.flutter.dev/install/archive),
[Riverpod](https://pub.dev/packages/flutter_riverpod),
[GoRouter](https://pub.dev/packages/go_router),
[Supabase Flutter](https://pub.dev/packages/supabase_flutter).
Metadatos de Flutter: `https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json`.

## Arquitectura y navegación

Organización por funcionalidades con espacios `data`, `domain` y
`presentation`. Los directorios vacíos se reservan con `.gitkeep`; no contienen
repositorios falsos ni operaciones de negocio. Se observa la sesión existente
del SDK mediante un repositorio tipado, un StreamProvider y un router estable.
UI y GoRouter no acceden directamente al cliente Supabase.

`StatefulShellRoute.indexedStack` contiene exclusivamente las cuatro pestañas.
Perfil es una ruta de soporte fuera de la barra. Los títulos y tooltips mantienen
los nombres completos; las etiquetas inferiores «¿Qué cocino?» y «Compra»
reducen la longitud en pantallas estrechas. Los widgets de Foundation indican
«Próximamente» y no representan consultas vacías de un backend inexistente.

La pantalla de acceso es informativa y navegable, sin bypass, usuarios de
demostración ni acciones de login ficticias. Registro, login, recuperación,
edición de perfil y cierre de sesión pertenecen a la Fase 03. Las identidades
controladas para probar las pestañas existen únicamente en `test/`.

## Configuración y privacidad

Configuración pública por `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` mediante
`--dart-define` o `--dart-define-from-file`. Se aceptan claves publishable y JWT
heredados con rol `anon`, rechazando roles administrativos. Esta validación es
sintáctica: no autentica claves ni reemplaza RLS. HTTPS obligatorio por ahora;
la configuración de Supabase local se decidirá en la Fase 02.

Sin configuración no se inicializa Supabase. Una inicialización válida tampoco
se anuncia como conexión remota verificada. Errores de sesión cierran el acceso;
errores del SDK no exponen tokens ni mensajes internos al usuario.

No se crearon tablas, RPC, políticas RLS, buckets ni datos remotos. Storage,
Realtime y permisos multiusuario continúan pendientes de su fase.

## Interfaz y reproducibilidad

Material 3, tema del sistema claro/oscuro, textos ARB `es_ES` generados con
`flutter gen-l10n`, estados empty/loading/error reutilizables y contenidos
desplazables para texto ampliado. Identificador técnico fijo y display name
MixTick tratados por separado. Se conserva el icono Flutter provisional.

`scripts/verify_foundation.ps1` conserva comandos, códigos de salida y evidencia
en `docs/reports/evidence/`. Los renders opcionales de widget son evidencia del
renderizado de prueba, nunca capturas de un dispositivo ni una sesión real.
No se implementan características de fases siguientes.
