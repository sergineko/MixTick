# Compra colaborativa: persistencia, sincronización e importación

## Roles

- Dueño (`shopping_lists.owner_id`): administra lista, invita, revoca, renombra, elimina y gestiona ítems.
- Miembro aceptado (`shopping_list_members`): consulta y gestiona ítems; puede salir de la lista; no puede invitar, expulsar ni borrar lista.
- Invitado pendiente: no tiene acceso a la lista hasta aceptar.
- Otros usuarios: acceso denegado.

## Regla de sincronización

PostgreSQL es la fuente de verdad; Realtime solo notifica cambios. Si hay desconexión o se pierde un evento, al reconectar ejecutar recarga autoritativa. No confiar en un cambio local no confirmado. Los toggles comprados deben evitar sobrescrituras desordenadas; verificar consistencia mediante `updated_at`/versionado si hay edición concurrente.

## Importar receta a compra

- Revisar en UI ingredientes, cantidad, unidad y lista destino antes de confirmar.
- Si receta privada: copiar exclusivamente datos necesarios de productos, sin nombre de receta ni identificador de receta en filas legibles por colaboradores.
- En importación desde ¿Qué cocino hoy?: copiar solo obligatorios faltantes, no opcionales salvo selección expresa.
- Crear `request_id` de importación y una clave idempotente por línea (`request_id + recipe_ingredient_ordinal`) para reintentos. Un nuevo acto del usuario genera nuevo `request_id` y puede volver a añadir artículos intencionadamente.
- Sumar cantidades solo si unidad normalizada y producto coinciden exactamente y ambos están pendientes, si la UX lo aprueba. Por simplicidad MVP, se puede **no fusionar** y mantener líneas independientes, siempre que no se dupliquen por reintento. No tocar marcados como comprados.
- Transacción para inserción de todas las líneas; si falla una, no dejar importación parcial.

## Escenarios de concurrencia

1. Persona A añade leche; B lo ve sin recargar al recibir evento.
2. A marca huevos; B marca pan; ambos cambios sobreviven.
3. B pierde internet -> A modifica -> B reconecta -> lectura completa.
4. Dueño retira a B -> eventos restantes no dan permiso de escribir/ver después de revocación.
5. A pulsa «Añadir a lista» y hay timeout; reintenta mismo request_id -> cero duplicados.
6. Dos miembros intentan editar mismo ítem: definir y probar política last-write-wins o versiones; no ocultar conflictos si pierden actualizaciones de cantidades.
