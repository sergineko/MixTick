# Pruebas de integración — Fases 03, 04 y 05

`auth_native_seed_test.dart` y `auth_native_restore_test.dart` ejercitan la UI
real Android, el almacenamiento seguro y la restauración entre procesos, contra
Supabase local aislado. El segundo test recibe el callback del correo real de
Mailpit por Android ACTION_VIEW mediante `scripts/deliver_native_recovery.py`.

Usar `scripts/verify_native_auth.ps1` con el emulador iniciado y el backend
arrancado por `scripts/start_isolated_supabase.ps1`. Es imprescindible
`--no-uninstall` entre ambos procesos. La sesión/fixture temporal se guarda
cifrada en el dispositivo y se retira al finalizar; el runner elimina únicamente
los UUID de cuentas devueltos por la prueba. No usa service_role ni cuentas remotas.

`test_support/auth_profile_local.dart` prueba repositorios Dart contra servicios
reales, en auto-confirmación y confirmación de correo. Su adaptador de PKCE en
memoria se identifica expresamente; un caso híbrido inyecta una caída de
transporte. Las pruebas de UI en `test/auth/` usan repositorios simulados y no
sustituyen RLS ni Auth reales.

Contrato, comandos y límites: [docs/16_AUTH_PROFILE.md](../docs/16_AUTH_PROFILE.md).
iOS necesita macOS/Xcode; no se declara probado en Windows. Cocina y compra,
Realtime/CDN y limpieza física siguen pendientes de sus fases/gates de lanzamiento.

## Mi recetario — Fase 04

`recipe_native_test.dart` ejecuta UI Flutter real en Android contra Auth,
PostgREST y Storage locales: crear/editar/pasos/publicar/privatizar/eliminar,
selección y cancelación en el Photo Picker, claro/oscuro y cambio de cuenta.
No hay repositorios simulados en esa prueba. `scripts/drive_recipe_gallery.py`
opera el diálogo nativo mediante la jerarquía UIAutomator observada: imagen
controlada única y confirmación Done de Android 17. Las capturas son del emulador.

Usar `scripts/verify_native_recipes.ps1`; véanse generación de fixture, arranque
aislado y comandos en [Mi recetario](../docs/17_MY_RECIPES.md). El runner conserva
datos del APK con --no-uninstall, fuerza un proceso nuevo, restaura modo noche,
retira solo el archivo/entrada MediaStore que creó y limpia las cuentas/fotos
de prueba verificadas. La limpieza host de fotos huérfanas necesita la API
privilegiada local después de perderse el acceso por borrado de receta; no está
en Flutter ni se usa para demostrar RLS. No representa un trabajador de producción.

`test_support/recipes_local.dart`: A/B/C reales y un caso híbrido identificado
de respuesta perdida después de un commit real. `test/recipes/` utiliza mocks
solo para validación, UI/controladores, conservación de borrador y conflictos.
Las pruebas/capturas Android no verifican iOS ni un dispositivo físico.

## Comunidad — Fase 05

`community_native_test.dart` usa UI Flutter y Auth/PostgREST/Storage locales
reales, con A/B/C creados por Auth: feed, like, guardado/Mi recetario/detalle,
comentarios y borrado propio, seguimiento, denuncia, bloqueo/desbloqueo,
privatización desde otra sesión y borrador aislado al cambiar cuenta.
`verify_native_community.ps1` fuerza un proceso nuevo sin borrar app data;
`capture_community_android.py` captura la pantalla real al observar marcadores
y cambia/restaura tema del emulador. La imagen es una fixture codificada
controlada; no una fotografía de producción. No hay repositorios simulados.

`test_support/community_local.dart` ejecuta tres clientes reales A/B/C.
Dos casos híbridos identifican pérdida de transporte y lectura real retrasada
durante cambio de Auth; no se cuentan como RLS adicional. `test/community/`
usa mocks para UI/estado; los tests de socket tienen actor y servidor de
transporte de test, sin probar autenticación.

Usar `verify_community.ps1 -BackendChecks -ResetLocal -IncludeNative
-IncludeAndroidBuild` con Pixel_10a activo. La regresión de recipe_native_test
mantiene su código original, captura en phase05/recipe-regression y retira
su única fixture de MediaStore. No sobrescribir evidencias históricas.
Scripts/apk/clientes se limitan a 127.0.0.1 o 10.0.2.2:54321. iOS, físico,
remoto, CDN, Realtime, worker y distribución siguen pendientes.

## ¿Qué cocino hoy? — Fase 06

010 añade `cook_today_page` invoker de lectura e índice de custom_key; conserva
las nueve migraciones, tablas, catálogo/alias y RLS anteriores. Matching en
servidor, cursor completo y respuesta limitada 8+1; no se descargan todas las
recetas al móvil. Contrato: [Cook Today](../docs/19_COOK_TODAY.md).

`scripts/verify_matching.ps1 -BackendChecks -ResetLocal -IncludeNative
-IncludeAndroidBuild` escribe exclusivamente evidencias de Fase 06 y ejecuta
las regresiones API/Auth/recetas/Comunidad y nuevas coincidencias. PowerShell 7.
`integration_test/matching_native_test.dart` usa A/B/C reales, selección,
modos, fotos, detalle original, privatización y cambio de identidad. No mocks
como evidencia de RLS. `verify_native_matching.ps1` obtiene configuración
pública local, captura pantalla real y limpia solo identidades/objetos propios.

`benchmark_matching.sql` usa 6.000 recetas temporales en rollback y un rol
SQL autenticado; no se presenta como Auth GoTrue ni rendimiento de producción.
No hay lista de compra funcional, remoto, Git, deploy o Fase 07 autorizados.
