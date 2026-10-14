# Lista de compra compartida — Fase 07

Alcance: módulo Compra y conexión a recetas/faltantes. No inventario, chat,
notificaciones push, cantidades disponibles, conversiones ni nuevas pestañas.
Los resultados ejecutados se detallan en el informe de Fase 07; este contrato
no sustituye sus evidencias.

## Datos y autoridad

Se conservan las cinco tablas públicas de compra de 001, RLS de 002, RPC de
003, publicación de 004 y cuotas/integridad de 006. Solo el propietario cambia
el título, elimina la lista o administra personas. Aceptar una invitación es
una transacción del destinatario. Productos editables por propietario/miembros
vigentes; desconocidos, pendientes, revocados y cuentas bloqueadas respecto
al propietario no adquieren acceso. Propietario no se duplica como miembro.

No existe `sort_order` en productos. Se muestran pendientes/comprados en orden
estable `created_at,id`. Nombre libre de productos domésticos no se convierte
automáticamente en alimento. Cantidad positiva hasta 1.000.000, tres decimales;
unidad opcional hasta 30 caracteres. Referencias canónicas se conservan al
copiar una receta; editar el nombre de compra no reescribe su FK histórica.

## Contratos aditivos 011

| Contrato | Alcance |
|---|---|
| `create_shopping_list_once` | Título, UUID de operación; actor de Auth; cuota histórica; tombstone tras eliminar |
| `add_shopping_item_once` | Producto libre/canónico validado; bloqueo de lista/permiso actual; UUID y payload invariables al reintentar |
| `shopping_list_snapshot` | Una sentencia invoker/RLS con cabecera, productos, miembros e invitaciones autorizadas; sin N+1 de red |
| `shopping_recipe_preview` | Una sentencia invoker/RLS con versión, raciones e ingredientes originales/IDs/ordinales; sin pasos/foto |
| `import_recipe_checked` | Revalida lista y receta, versión, pares ID/ordinal; copia atómica a través de RPC histórica |
| `shopping_invitation_inbox` | Proyección mínima para receptor pendiente: título de la lista y username público del remitente; no productos/miembros |

La tabla técnica **privada** `shopping_requests` liga actor/request/tipo/hash/IDs.
No está expuesta por API o Realtime, tiene RLS y no grants a clientes. Definers
usan search_path vacío y no reciben un actor arbitrario; wrappers son invoker.
No se editan 001–010. El ledger histórico de importación sigue vigente.
Cambiar destino/selección con la misma operación produce conflicto. Un retry
ya confirmado devuelve sus IDs originales incluso tras eliminar productos o
cambiar receta, revalidando acceso actual, sin recrear ni destachar nada.

La bandeja de invitaciones concede explícitamente el **título** de la lista
invitada, además del remitente público. No concede acceso a su contenido;
el receptor sigue sin poder leer la lista hasta aceptar. No hay email/Auth
metadata. Bloqueos simétricos y vigencia del propietario se verifican en SQL.

## Importación y faltantes

Detalle de receta: «Añadir ingredientes a la lista», destino explícito y
checkboxes de revisión. Se copian cantidades/unidades/raciones originales,
sin escalado, conversión, suma entre líneas ni cambio de comprado. Cantidades
pueden editarse después como productos de la lista, con versión actual.
Ni título, autor, descripción, pasos, foto ni ID privado de receta se copian a
productos. `source_key` histórico es un hash opaco de actor/request/ordinal.

Un resultado de matching con faltantes pasa su DTO original al detalle.
«Añadir lo que me falta» usa exclusivamente sus líneas obligatorias, IDs,
ordinales, cantidades y unidades; cero faltantes no presenta esa acción.
Preview fresco comprueba versión/identidades. Si cambian, exige regresar a
«¿Qué cocino hoy?» y revisar una consulta nueva conservando la selección de
presencia en la sesión. No se adivina qué nuevos ingredientes tiene el usuario.
Confirmación SQL vuelve a validar para cerrar la carrera entre preview y commit.
No se modifica el algoritmo/paginación de 010 ni su benchmark pendiente.

UUID/payload de una importación permanecen invariables ante una respuesta de
transporte ambigua. El reintento reconcilia esa operación; una nueva importación
deliberada obtiene otro UUID. No hay modo offline completo ni cola persistente.

## Realtime y ciclo de vida

Publicación real existente: únicamente INSERT/UPDATE de `shopping_lists` y
`shopping_items`. No DELETE ni membresías publicadas. Sus triggers incrementan
la versión de lista cuando se elimina un producto o cambia una membresía.
Los eventos son **señales**, nunca sustitutos de autorización ni parches de UI.
Se agrupan durante 200 ms y se lee un snapshot RLS; así, señales repetidas o
fuera de orden no duplican productos. Versiones esperadas evitan pérdida
silenciosa de ediciones. Toggle optimista termina en lectura autorizada incluso
si la escritura falla. Una lectura denegada/error descarta el agregado visible.

Se abre un canal solo después de una lectura autorizada. La confirmación
Phoenix no equivale a replicación preparada: `system status=ok` activa estado
conectado; reconexión preparada dispara snapshot. SDK conserva un WebSocket
por cliente y un canal por detalle visible. Cambiar lista, cubrir detalle,
cerrar sesión o perder permiso cierra el canal/timers. Al regresar se construye
estado nuevo. Cada respuesta comprueba identidad/generación; no caché ajena
persistida. Widget no accede al SDK.

Un expulsado ya no recibe el UPDATE porque la RLS deja de autorizarlo; una
lista borrada tampoco produce DELETE. Por eso el detalle visible comprueba
acceso cada **15 s**, además de regreso, foreground, reconexión y recarga manual.
No se promete retirada instantánea de un frame ya descargado ni de copias.
La bandeja/listado revalida manualmente, al regresar y periódicamente cada
30 s visible; no se abre otro WebSocket para invitaciones no publicadas.
El editor comprueba acceso al regresar/foreground y cada 30 s; ante denegación
cierra y descarta campos protegidos. Una lectura inicial fallida se puede
reintentar desde la recarga; no se deja el botón sin efecto.

## Reproducción

`scripts/verify_shopping.ps1`: calidad y, con `-BackendChecks -ResetLocal`,
reset exclusivo local tras verificar cero cuentas, SQL/API y regresiones Auth,
recetas, Comunidad, matching y compra. `-IncludeNative` requiere el emulador
controlado activo. `verify_native_shopping.ps1` conserva capturas/logs separados
de fases anteriores; `cleanup_shopping_fixtures.py` solo elimina sus identidades
registradas `mixtick-p7-* @example.test` y objetos propios. La clave administrativa
local se limita al teardown host de fixtures; jamás a Flutter o prueba de RLS.

Compatibilidad contrastada con SDK instalado y fuentes oficiales:
[suscripciones Dart](https://supabase.com/docs/reference/dart/subscribe),
[Postgres Changes/RLS](https://supabase.com/docs/guides/realtime/postgres-changes),
[eliminar canal](https://supabase.com/docs/reference/dart/removechannel).
No dependencia/pin nuevos. Supabase Flutter 2.18.3/RealtimeClient 2.13.2 instalados.

Gates de distribución preservados: iOS/físico, backend remoto/correo/CDN,
worker físico, eliminación completa de cuenta, moderación operativa y
optimización general del matching antes del lanzamiento correspondiente.
