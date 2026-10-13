# Política de identificadores técnicos — Sergiotech

## Contrato obligatorio del proyecto

| Campo | Valor exacto |
| --- | --- |
| Organización Flutter (`--org`) | `es.sergiotech` |
| Nombre Dart/Flutter (`pubspec.yaml: name`) | `mixtick` |
| Android `applicationId` | `es.sergiotech.mixtick` |
| Android `namespace` | `es.sergiotech.mixtick` |
| Android `MainActivity.kt` declaración `package` | `es.sergiotech.mixtick` |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` (Runner Debug/Profile/Release) | `es.sergiotech.mixtick` |
| Nombre comercial visible | `MixTick` (sujeto a comprobación de marca) |

**Regla transversal de Sergiotech:** siempre `es.sergiotech.<nombre_normalizado>` para las apps. En este proyecto la normalización acordada de MixTick es `mixtick` en minúsculas.

No utilizar `com.example.mixtick`, `com.mixtick.app`, `recipe_social_app` o identificadores autogenerados distintos. No tratar el paquete como una variable de branding; tras distribuir en Play/App Store, cambiar el identificador equivale a crear otra app para las tiendas.

## Generación desde cero

Desde la raíz extraída (tras comprobar que no exista ya código Flutter):

```powershell
flutter create --org es.sergiotech --project-name mixtick --platforms=android,ios .
flutter pub get
py -3 scripts/check_identifiers.py --strict
```

Si `py` no está disponible, usar `python`. Las comprobaciones también pueden hacerse manualmente:

- `pubspec.yaml`: `name: mixtick`.
- `android/app/build.gradle.kts` o `.gradle`: `namespace` y `applicationId` iguales al valor exacto.
- `android/app/src/main/kotlin/es/sergiotech/mixtick/MainActivity.kt` (o Java equivalente): cabecera `package es.sergiotech.mixtick`.
- `ios/Runner.xcodeproj/project.pbxproj`: todas las líneas `PRODUCT_BUNDLE_IDENTIFIER` para Runner apuntan al valor aprobado; si hay targets de pruebas, pueden requerir un identificador derivado propio.

Si el comando CLI genera valores diferentes, corregirlos antes de dar por completada la fase 01 y volver a ejecutar verificaciones.

> Generar `ios/` en Windows es posible, pero compilar y firmar para iOS requiere macOS con Xcode. Sin macOS, reportar las pruebas iOS como `NOT_RUN`, nunca `PASS`.

## Rename / marca

Cambiar el nombre que ve el usuario no cambia estos identificadores. Toda modificación al paquete exige aprobación explícita y revisión de la publicación en tiendas. Evitar cambiar IDs entre fases sin necesidad.
