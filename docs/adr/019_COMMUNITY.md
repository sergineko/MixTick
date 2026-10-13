# ADR-019 — Comunidad y referencias guardadas

Estado: implementación de Fase 05 autorizada; validación en su informe local.
Fecha: 2026-10-13. Conserva ADR-001–018 y las ocho migraciones aceptadas.

Se añade 009 para proyecciones invoker que calculan feed/búsqueda/recuentos
bajo RLS en una sola petición. El cursor usa publicación inicial/UUID
descendentes. Guardados y recetas públicas de autor comparten esa consulta
y el modelo Recipe. Los ingredientes se buscan por alias/canónico completo
o igualdad normalizada de texto libre; no se inventan equivalencias.

Se conservan INSERT/DELETE, PK y RLS de likes/saves/follows/blocks, así como
submit_report, quotas, fotografías y RPC de recetas. Acciones no optimistas
se reconcilian desde servidor; revisión compartida invalida pantallas. Las
consultas obsoletas se abortan y descartan, y los borradores se aíslan por actor.

Los comentarios emplean un ledger privado por actor/request, UUID de comentario
generado por servidor y tombstone al eliminar. Así, repetir una respuesta perdida
no duplica ni permite usar request IDs para averiguar la existencia de contenido
ajeno. CHECK aditivo rechaza comentarios que solo contienen whitespace.

Se revalida acceso al abrir/volver/activar/foreground y cada 30 s visible,
ocultando datos durante carga/error. No se habilita Realtime ni se promete
retirar una copia ya descargada. Moderación mínima usa contratos existentes;
moderación operativa y eliminación de cuenta permanecen gates de lanzamiento.
Sin nuevas dependencias, módulos, commits/push, remoto, deploy o Fase 06.
