# Arquitectura técnica prevista

## Tecnologías

- Flutter + Dart (versions estables compatibles verificadas al comenzar).
- Riverpod para estado y controladores; GoRouter para rutas y guards.
- Supabase: Auth, PostgreSQL, Storage privado, Realtime.
- SQL migrado y versionado con Supabase CLI; Flutter Test, pruebas de integración y pruebas RLS independientes.
- No incluir un servidor Node independiente ni microservicios si Supabase resuelve el caso.

## Esquema de carpetas a CREAR POR LA IA (no es código incluido en el ZIP)

```text
lib/
  main.dart
  app/{app.dart,router.dart,theme/,localization/}
  core/{config/,errors/,network/,utils/,widgets/}
  features/
    auth/{data/,domain/,presentation/}
    profile/{data/,domain/,presentation/}
    community/{data/,domain/,presentation/}
    recipes/{data/,domain/,presentation/}
    cook_today/{data/,domain/,presentation/}
    shopping/{data/,domain/,presentation/}
  shared/{models/,widgets/}
supabase/{migrations/,seed.sql,tests/}
test/
integration_test/
assets/{images/,icons/}
docs/
```

## Contratos y repositorios orientativos

- AuthRepository: signIn/signUp/resetPassword/signOut/currentSession.
- RecipeRepository: create/update/delete/setVisibility/loadMine/loadSaved/findPublic/readAccessible.
- CommunityRepository: feed/search/follow/like/save/comment/report/block.
- IngredientRepository: searchApprovedCatalog/normalizeAlias; texto libre restringido donde proceda.
- MatchingRepository: findExact/findNear con filtros de acceso.
- ShoppingRepository: createList/loadMine/invite/acceptInvitation/editItems/importIngredients/watchList.

Una pantalla no accede directamente a Supabase: pasa por controlador / proveedor / repositorio. DTOs tipados, errores de dominio, cancelación y paginación.

## Calidad

- `flutter analyze`, `flutter test`, formato `dart format`, migraciones reproducibles, pruebas SQL RLS y pruebas widget/integración.
- Supabase URL y clave pública/configurable por `--dart-define` o mecanismo correcto compatible. Nunca service_role ni secretos administrativos embebidos.
- ID técnico de esta aplicación **fijo**: Android `applicationId` y `namespace` = `es.sergiotech.mixtick`; iOS `PRODUCT_BUNDLE_IDENTIFIER` = `es.sergiotech.mixtick` en todas las configuraciones del MVP. Organización Flutter `es.sergiotech`, nombre Dart `mixtick`. El display name es independiente. Revisar `docs/13_PACKAGE_IDENTIFIERS.md`.
- No usar generador de código si incrementa la complejidad sin ventaja demostrable.

## Bootstrap obligatorio (raíz del repositorio)

```powershell
flutter doctor
flutter create --org es.sergiotech --project-name mixtick --platforms=android,ios .
flutter pub get
py -3 scripts/check_identifiers.py --strict
```

Si el comando `py -3` no está disponible, usar `python`. En Windows se puede **generar** la carpeta iOS, pero compilar y firmar la aplicación iOS requiere macOS y Xcode. Antes de crear, la IA debe revisar si ya existe un proyecto Flutter y nunca sobrescribir código útil.
