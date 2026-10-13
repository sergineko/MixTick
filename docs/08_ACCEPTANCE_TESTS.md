# Matriz de aceptación / pruebas obligatorias

Estados posibles en informes: `PASS` (ejecutado y verificado), `FAIL`, `NOT_RUN` (no disponible), `BLOCKED` (dependencia), `NOT_APPLICABLE` (justificado).

| ID | Categoría | Escenario | Resultado esperado |
|---|---|---|---|
| A01 | Auth | registro + validación + acceso + salida | sesión coherente; rutas protegidas |
| A02 | Auth | restablecimiento contraseña | enlace/acción verificada sin exponer secretos |
| R01 | Recetas | usuario A crea receta | `private` como valor efectivo por defecto |
| R02 | Privacidad | usuario B consulta receta privada de A por UUID directo | acceso denegado en servidor |
| R03 | Privacidad | B consulta ingredientes, pasos y foto de la privada | acceso denegado en servidor |
| R04 | Recetas | A publica -> B ve -> A despublica | deja de aparecer y de ser accesible por B |
| R05 | Recetas | crear/editar con fallo intermedio | no deja receta en estado parcialmente roto |
| C01 | Comunidad | búsqueda paginada de públicas | resultados sin duplicados y solo autorizados |
| C02 | Comunidad | likes/saves/follows repetidos | sin duplicados |
| C03 | Comunidad | B guarda pública y A despublica | B no puede recuperarla desde guardados |
| C04 | UGC | reportar/bloquear y borrar comentario propio | autorizaciones y feedback |
| M01 | Matching | exacta por IDs normalizados | solo si contiene todos los obligatorios |
| M02 | Matching | falta 1 o 2 | resultados y número de faltantes correctos |
| M03 | Matching | alias tomate/tomates | mismo ingrediente canónico |
| M04 | Matching | opcional ausente | no excluye coincidencia |
| M05 | Matching | resultados disponibles para usuario | propias privadas sí, ajenas privadas no |
| M06 | Matching | cantidades disponibles | nunca afirmar comprobación de cantidades |
| S01 | Compra | crear, editar, tachar y borrar ítems | estado persistido correcto |
| S02 | Compra | invitación por usuario registrado | acceso solo tras aceptación |
| S03 | Compra | otro usuario sin membresía consulta por UUID | 0 filas; update/insert/delete denegados |
| S04 | Compra | usuario autorizado agrega/tacha y segundo ve | sincronización en sesiones independientes |
| S05 | Compra | pérdida de conexión Realtime | vuelve a estado correcto al reconectar |
| S06 | Compra | reintento importación con misma request_id | idempotente, sin líneas repetidas |
| S07 | Compra | importe desde receta privada | otro miembro ve solo ítems, no datos privados de receta |
| S08 | Compra | revocar membresía | lectura y escritura posterior denegadas |
| X01 | Integración | receta -> comparar ingredientes -> añadir faltantes -> compra compartida | flujo sin incoherencias |
| X02 | Calidad | flutter analyze, flutter test, migraciones, RLS tests | evidencias vinculadas en reporte |
| X03 | Cuenta | eliminación de cuenta y sus archivos | elimina/minimiza datos correctamente |

Probar como mínimo con cuentas ficticias distintas A y B, idealmente C para acceso denegado. Datos de prueba no deben quedar en producción.
