# ADR-018 — Mi recetario real y fotografías seguras

Fecha: 2026-10-13. Estado: implementada bajo autorización exclusiva de Fase 04.

Contexto: los siete SQL aceptados ofrecen agregado atómico/versionado, publicación
explícita y bucket privado. Una UI móvil añade respuestas perdidas, cambio de
cuenta, fotos temporales y sustitución; los contratos iniciales no cubrían su
idempotencia ni la limpieza de fotos sustituidas.

Decisión: mantener las migraciones históricas y ampliar con 008. Crear con
actor/request/hash en ledger privado y RPC invoker, reconciliar UUID propio,
editar con save_recipe existente y borrar con una operación versionada nueva.
Conservar los entry points anteriores para compatibilidad. RLS y Auth son
autoridad; las comprobaciones de UI no sustituyen sus políticas.

Fotografía es una operación posterior al agregado completo, nunca se sobrescribe
el archivo válido. Nueva referencia requiere existencia/versión; anterior o
temporal se encola y deja de ser legible por terceros cuando deja de ser vigente.
El bucket y descarga son privados/autenticados. El trabajador físico no se
implementa: se exige gracia para staging y referencia coordinada antes de borrar.
No prometer atomicidad Storage/SQL ni revocación de capacidades ya firmadas/copias.

Estado por usuario, respuestas tardías descartadas, borradores y diálogos se
eliminan al cambiar cuenta. Caché de imagen solo en memoria y desalojada al
liberar proveedor/formulario. Conflictos requieren recarga confirmada; errores
recuperables preservan el formulario. Publicar/privatizar/eliminar son acciones
explícitas con explicación y confirmación.

Lista propia con ILIKE escapado, categorías reales, visibilidad y cursor de
updated_at/id. Catálogo/alias existentes y RPC resolve_ingredient, sin una
normalización heurística que invente equivalencias; texto libre acotado cuando
la resolución devuelve null. Campos/unidades respetan checks reales, sin enums
SQL imaginarios. Pasos por orden del array y lectura por ordinal.

Se reutilizan picker/procesador de Fase 03 (2 MiB/1024 px, más estricto que el
bucket). No hay dependencias nuevas ni cambios de versiones/identificadores.
RecipeContent sirve para fases futuras, sin controles sociales/compra/cocina.
Guardadas es informativo hasta Fase 05. Regresión aceptada y pruebas nuevas
distinguen mocks, servidor A/B/C real, fallo híbrido y Android real; iOS pendiente.
No commits, push, despliegues ni avance de fase. Contrato completo:
[Mi recetario](../17_MY_RECIPES.md).
