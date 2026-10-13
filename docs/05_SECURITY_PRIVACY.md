# Seguridad, privacidad y contenidos compartidos

## Identidad

- Supabase Auth con confirmación de correo si está habilitada; `profiles.user_id = auth.uid()`.
- No exponer email en `profiles` ni respuestas públicas.
- Username único no sensible a mayúsculas; invitaciones por username, nunca por lectura de tablas de Auth.

## Matriz de acceso simplificada

| Recurso/acción | Visitante sin sesión | Autenticado cualquiera | Propietario | Miembro de compra |
|---|---|---|---|---|
| Leer receta pública | no (v1 exige login) | sí salvo bloqueo aplicable | sí | n/a |
| Leer receta privada | no | no | sí | n/a |
| Editar receta | no | no | sí | n/a |
| Ver pasos/ingredientes privados | no | no | sí | n/a |
| Crear comentario/like | no | sí en receta pública | sí en su pública | n/a |
| Ver compra ajena | no | no | dueño sí | sí en su lista |
| Modificar productos | no | no | sí | sí |
| Gestionar miembros | no | no | sí | no |
| Aceptar invitación | no | solo invitado destinatario | si destinatario | n/a |

RLS habilitada en **todas** las tablas expuestas, incluidas relaciones, comentarios, invitaciones, bloques, denuncias. Verificar con tokens no privilegiados. Limitar accesos a storage y RPC de acuerdo con `auth.uid()`.

## Foto de receta

Usar bucket(s) privados y políticas de Storage vinculadas a acceso actual a receta, o un mecanismo equivalente probado. Rutas de archivo con IDs impredecibles. Si se emiten URLs firmadas, duración corta y cuidado: una URL ya emitida puede seguir utilizable hasta caducar tras retirar publicación; no prometer revocación instantánea de URLs existentes. Definir TTL, estrategia de caché y borrado antes del despliegue.

## Invitación segura

La aceptación debe ser atómica y comprobar en servidor: destinatario correcto, pendiente, lista vigente, invitado no bloqueado si aplica y que el propietario sigue siendo quien invita. Debe crear membresía una sola vez. Revocar membresía impide futuras lecturas y escrituras. Transacciones/RPC SECURITY DEFINER, si necesarias, con `search_path` cerrado, validación explícita de usuario y permisos EXECUTE mínimos.

## Contenido generado por usuario (UGC)

- Denunciar recetas/comentarios/perfiles, bloquear usuarios, eliminar comentario propio y controles mínimos de moderación.
- Reglas de comunidad y condiciones de uso antes de distribuir públicamente.
- No permitir URLs arbitrarias maliciosas ni HTML inyectado en descripciones/comentarios; limites de tamaño y normalización de texto.
- Verificar que bloquear oculta interacciones relevantes, y que no abre puertas a consultar datos privados.
- Ratios/límites razonables de creación de comentarios, recetas, reportes e invitaciones.

## Legislación y publicación

Información de privacidad, tratamiento y eliminación de cuenta/datos (RGPD y políticas de tiendas según mercados) debe revisarse antes del lanzamiento real; no presentar el producto como legalmente certificado. Eliminar cuenta debe considerar propiedad de listas con miembros, referencias, fotos, comentarios y datos de Auth sin dejar filas huérfanas.

## Pruebas negativas obligatorias

- Usuario B hace SELECT directo a receta privada de A: 0 filas.
- B intenta lectura de ingredientes, pasos, rutas privadas, comentarios/likes de receta privada de A: denegado.
- B conoce ID de lista de A: 0 filas/edición fallida si no es miembro.
- B inventa una invitación con identidad de A: denegado.
- Miembro expulsado intenta editar mediante API directa/reconexión: denegado.
- URL firmada caducada deja de servir foto privada.
- Escalada a RPC/admin/service_role desde móvil: no posible.
