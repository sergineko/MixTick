# Fotografías de recetas — privacidad y caducidad

La migración `20261013000400_storage_realtime.sql` crea `recipe-photos` con
`public = false`, máximo 5 MiB y tipos JPEG/PNG/WebP. La ruta obligatoria es
`<autor_uuid>/<receta_uuid>/<foto_uuid>.<jpg|png|webp>`; el nombre de archivo no
incluye títulos ni datos personales. Se valida formato, existencia de receta y
correspondencia del autor. Subir/modificar/borrar exige ser autor; leer/listar
exige acceso vigente a la receta. Un bucket público nunca sirve estas fotos.

## Acceso temporal

Preferir la descarga autenticada del SDK: cada petición con JWT de usuario
comprueba RLS vigente. Al hacer una receta privada, otro usuario deja de poder
descargar, listar o emitir nuevas URLs firmadas. No se utiliza service_role en
Flutter, ni se guarda una URL permanente en recipes: solo `hero_image_path`.

Cuando la futura UI necesite una URL firmada, solicitarla con el JWT del usuario
autorizado y `expiresIn = 60` segundos. Configurar caché `max-age=0`, no conservar
imágenes privadas en caché persistente y revalidar permisos al reabrir pantallas.
Al reemplazar/borrar imagen se debe eliminar el objeto antiguo con Storage API
o encolar su limpieza; no basta borrar una fila de metadata por SQL.

**Límite real:** Storage firma una capacidad temporal; una URL ya emitida sigue
sirviendo hasta caducar aunque cambie la privacidad. Los 60 segundos son el
contrato del cliente de primera parte, no un máximo que estas políticas RLS
puedan imponer al parámetro expiresIn de un cliente autorizado. No se promete
revocación instantánea. Antes de habilitar URLs firmadas en la app debe decidirse
si se mantiene descarga autenticada o se centraliza/enforce la emisión con TTL
mínimo en un backend de confianza. Un destinatario que ya descargó bytes puede
conservarlos: ninguna política puede retirar una copia descargada.

La eliminación efectiva del objeto corta futuros accesos al origen; comportamiento
de CDN/cachés remoto debe verificarse en su entorno. No se extrapolan las pruebas
locales al CDN de producción. Fotos huérfanas son inaccesibles por RLS al no
existir receta, y quedan en `private.storage_cleanup_jobs` para eliminación
física. El trabajador de esta cola aún no está implementado ni desplegado.

## Evidencia real de Fase 02

`test_11` de `scripts/test_database_api.py` crea una imagen PNG controlada con
Storage API y el token real de A. B/C no pueden descargarla ni listar la ruta
ni firmarla cuando la receta es privada. El endpoint público tampoco sirve
la imagen. B no puede subir un archivo en la ruta de A.

Después de publicar, B puede descargar los bytes y emitir una URL firmada con
TTL de 3 s. Tras volver a private, su descarga autenticada y una nueva firma
se deniegan; la URL existente sigue funcionando antes de caducar y deja de
servir la imagen tras esperar 4 s. La prueba hace explícita esa ventana.

`test_18` verifica en PostgreSQL real, dentro de una transacción con rollback,
que borrar la receta encola su objeto para limpieza. No afirma que un trabajador
haya eliminado físicamente el archivo. Las fixtures se retiran mediante Storage
API antes de borrar sus cuentas locales.

Fuentes oficiales: [Storage/RLS](https://supabase.com/docs/guides/storage/security/access-control),
[buckets privados](https://supabase.com/docs/guides/storage/buckets/fundamentals),
[URLs firmadas y caché](https://supabase.com/docs/guides/storage/cdn/smart-cdn).
