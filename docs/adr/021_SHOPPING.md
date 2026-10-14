# ADR-021 — Compra compartida y receta revisada

Estado: implementación de Fase 07 autorizada, revisión del propietario pendiente.

Reutilizar todas las tablas/RLS/RPC aceptadas. 011 añade snapshots invoker,
inbox mínimo ligado a invitación explícita y ledger privado para creación e
importación de una receta revisada. Evita duplicados tras respuesta perdida y
una carrera que podría copiar otros ingredientes después de modificar receta.
Ninguna migración histórica cambia, ningún módulo adicional aparece.

Realtime notifica; PostgreSQL RLS decide y devuelve snapshot. INSERT/UPDATE
existentes, nunca DELETE sin revalidación. System readiness separado del join;
debounce, recarga al reconectar y probe de 15 s cierran el caso de borrado/
revocación cuyo evento ya no es autorizado. Versiones de producto y predicado
atómico de versión en título/borrado rechazan cambios concurrentes.

Importación no suma cantidades, convierte unidades, escala raciones ni
destacha productos. Solo copia campos de ingrediente, sin procedencia privada.
Faltantes originales se reconcilian por versión/IDs antes de confirmar; cambio
de receta requiere consulta nueva. El algoritmo de Fase 06 queda conservado.

Evidencias separan SQL de estructura, Auth/API reales, WebSockets independientes,
Android real y mocks de UI/transporte. La tabla de resultados del informe es
la autoridad para PASS/FAIL/NOT_RUN; límites remotos/iOS y gates de lanzamiento
se conservan. No Git/deploy ni Fase 08 sin nueva autorización.
