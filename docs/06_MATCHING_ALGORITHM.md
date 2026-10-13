# Algoritmo para «¿Qué cocino hoy?» — Fase 06

La migración 010 ejecuta este contrato en PostgreSQL como el llamante bajo RLS.
La selección es temporal y expresa presencia, sin cantidades disponibles de casa.

## Entradas y claves

- Hasta 50 entradas brutas combinadas: UUID de catálogo aprobado y nombres libres
  de 1–80 caracteres. Los nombres se normalizan y resuelven por alias registrado
  completo. No se singulariza ni se compara por subcadenas.
- Prioridad: UUID canónico. Texto libre de receta que ahora tiene un alias
  inequívoco aprobado se compara por ese UUID, incluso si conservaba custom_name.
- Si no se resuelve, se usa únicamente la igualdad de custom_key normalizada.
  «Miso» no coincide con «Miso blanco»; «aceite» no implica oliva ni girasol.
- Catálogo/alias existentes son la única autoridad de equivalencias; no se
  infieren sustituciones, básicos disponibles ni relaciones nutricionales.
- Las selecciones/alias se deduplican antes de comparar. Las líneas de receta se
  agrupan por clave efectiva. Una clave presente en una línea obligatoria y otra
  opcional se considera obligatoria; las cantidades originales se conservan.

## Conjuntos y condiciones

Sea R el conjunto de claves obligatorias y S la selección efectiva:

`presentes = |R ∩ S|`, `faltantes = |R − S|`.

Opcionales no excluyen coincidencias y nunca se muestran como faltantes
obligatorios. No se compara quantity/unit con ninguna existencia doméstica.
La UI advierte que las cantidades disponibles no se comprueban.

- Selección vacía: cero resultados y sin búsqueda costosa.
- Recetas sin obligatorios: excluidas de ambos modos. No crean coincidencias
  universales engañosas, aunque tengan opcionales seleccionados.
- Puedo cocinarlo / exact: R no vacío y faltantes = 0.
- Me falta poco / near: R no vacío, presentes ≥ 1 y faltantes ≤ 2. Incluye
  completas primero, diferenciadas con «Puedes prepararla»; después «Te falta
  1 ingrediente» y «Te faltan 2 ingredientes». Esta regla concreta sigue la
  autorización de Fase 06 más reciente.

## Orden determinista y paginación

Completa: opcionales coincidentes DESC, tiempo total ASC, UUID ASC.
Parcial: faltantes ASC, obligatorios coincidentes DESC, tiempo total ASC, UUID ASC.
No se introduce score, popularidad, azar o recomendador. Un resultado de dos
faltantes nunca precede a otro de uno por ser más rápido.

El tiempo reutiliza Recipe.totalMinutes: suma de los componentes indicados,
tratando el componente no indicado como cero; si faltan ambos, tiempo desconocido
al final (sentinela interno 20161, mayor que el máximo posible 20160).
No se presenta el tiempo desconocido como cero. No se añade recencia como
criterio; el UUID resuelve empates de forma estable sin modificar el feed.

Cursor ASC: `(missing, rank, minutes, id)`; rank es el negativo del número de
opcionales coincidentes para completas y el negativo de obligatorios coincidentes
para parciales. Se devuelve la siguiente página con una comparación estricta del
cuádruple, límite 1–50. El cliente pide 8+1 y deduplica IDs al unir páginas.
Ediciones concurrentes pueden cambiar la posición de una receta: refresh vuelve
al comienzo; no se promete snapshot estable.

## Fuente y privacidad

Una única lectura de recipes bajo sus RLS incluye propias públicas/privadas y
públicas ajenas autorizadas. Saved no se une como otra fuente ni concede acceso.
RLS se aplica también a ingredientes, alias y perfiles. Bloqueos son simétricos
según el contrato histórico. No hay contador global o datos de candidatas privadas
ajenas en la respuesta, ni pasos descargados para comparar en el móvil.

Solo se puntúan en servidor candidatas con al menos un obligatorio coincidente.
La respuesta limitada contiene cabecera, autor mínimo, recuentos propios de
coincidencia y líneas faltantes originales. La búsqueda es una RPC invoker;
no se usa una vista definer o un bypass de permisos.

## Texto libre, faltantes y límites

Texto libre desconocido requiere nombre completo normalizado exacto: términos
parecidos no son equivalentes. La normalización española visual se reutiliza
para chips; el backend aplica la normalización autoritativa existente y resuelve
alias de nuevo. Nombres ambiguos solo coinciden con el mismo literal desconocido,
no con ingredientes canónicos más específicos.

MissingIngredientsTransfer retiene versión/UUID de receta, identidad y ordinal
de cada línea, nombre/FK original, UUID efectivo si procede, cantidad y unidad
requeridas. Si una clave faltante se repetía en líneas originales, cada línea se
conserva en el DTO, mientras el recuento es por clave distinta. Fase 07 deberá
revalidar acceso/versión antes de importar. En Fase 06 no se escribe ninguna lista.

Pruebas reales, rendimiento local, capturas y límites:
[contrato del módulo](19_COOK_TODAY.md),
[informe](reports/PHASE_06_REPORT.md). iOS/remoto y los gates de lanzamiento
anteriores siguen pendientes. Las copias descargadas no se revocan retroactivamente.
