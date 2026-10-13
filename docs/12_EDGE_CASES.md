# Casos límite que la IA debe contemplar

1. Usuario borra una receta: cascadas seguras en ingredientes/pasos; guardados y likes removidos; imágenes borradas sin exponer URL.
2. Usuario despublica receta: feed y favoritos de otros la ocultan; la URL firmada previa podría subsistir hasta caducar; diseñar TTL corto.
3. Autor y seguidor se bloquean: evitar que contenidos e interacciones de usuario bloqueado se muestren cuando corresponda.
4. Ingrediente aparece como alias y principal: evitar duplicar chips y recuentos de coincidencia.
5. Receta sin fotografía: renderizar placeholder sin exigir fotografía real.
6. Ingredientes opcionales: no contaminar recuento de faltantes, pero ofrecer inclusión manual en compra.
7. Cantidad no especificada: guardar nombre sin fingir cantidad.
8. Dos listas con mismo nombre: no colisionar ID, puede permitirse; preguntar antes de borrar.
9. Dos usuarios editan mismo ítem durante caída de red: mecanismo de reconciliación definido y probado.
10. Invitación a username inexistente, a uno mismo o repetida: mensaje claro, prevenir duplicados.
11. Invitación pendiente y lista eliminada: no debe habilitar membresía huérfana.
12. Miembro revocado con sesión abierta: fallo de autorización inmediato en siguiente consulta/modificación.
13. Repetición de botón importar por latencia: misma `request_id` no duplica.
14. Usuario sin receta/compra o sin resultados: empty states útiles sin falsos éxitos.
15. Documento con contenido malicioso en receta o comentario: mostrar como texto seguro, limitar tamaños.
16. Cuenta eliminada propietaria de listas con miembros: definir antes política (eliminación o transferencia explícita), informar usuarios.
17. Feed paginado cuando receta se despublica: no mostrarla en cachés sin revalidación de visibilidad.
18. Imágenes grandes/red lenta: subida con feedback y cancelación, sin dejar referencias rotas.
