# Fase 08 — Operaciones, eliminación y preparación local

Fecha de auditoría: 2026-10-14. Solo entorno local. No se ha autorizado ni
ejecutado despliegue, programación remota, firma de distribución o publicación.
Las migraciones 001–011 son históricas y se conservan intactas; aplicar después
012–015 mediante el proceso de migración revisado cuando se autorice.

## Trabajador de imágenes

`supabase/functions/cleanup-storage` consume `private.storage_cleanup_jobs`.
La clave administrativa vive exclusivamente en el entorno servidor. La función
exige POST y un secreto dedicado `MIXTICK_WORKER_SECRET` de al menos 32 caracteres
en `x-mixtick-worker`. Un JWT ordinario o la clave pública no lo sustituye.
Solo esta función usa `verify_jwt=false`, porque su autenticación es la del
trabajador. `delete-account` conserva la verificación JWT y valida además al
usuario vivo con GoTrue. No utilizar `--no-verify-jwt` globalmente.

La subida crea un trabajo de staging; el enlace válido lo retira. La sustitución,
retirada o borrado de una receta/avatar encola el objeto antiguo. Gracia normal:
24 horas. El borrado de cuenta confirmado adelanta exclusivamente sus propios
objetos, ya retiradas sus referencias. La API de Storage realiza el borrado
físico: borrar solo una fila de `storage.objects` no sería suficiente.
[Referencia oficial](https://supabase.com/docs/guides/storage/management/delete-objects).

Cada lote reclama como máximo cinco objetos. `FOR UPDATE SKIP LOCKED` evita
dobles reclamaciones; un UUID de claim y una lease de dos minutos descartan
finalizaciones tardías. La reclamación comprueba bucket, ruta UUID estricta,
propietario en cola/ruta/Storage y referencia actual. Un objeto actualmente
referenciado se conserva. Antes del DELETE se vuelve a validar el claim.

La reclamación instala una barrera persistente (`fenced`): los escritores de
referencias y las subidas coordinan el mismo trabajo con bloqueo de fila.
Si la referencia volvió antes de reclamar, se conserva; una vez reclamado no
puede volver a enlazarse esa ruta. Esto cierra el intervalo entre comprobar una
referencia y eliminar físicamente su archivo, incluso tras caída del proceso.
Una nueva imagen debe usar una ruta UUID nueva. La lease caducada permite
recuperación; nunca se libera la barrera para facilitar un reintento.

Los errores usan categorías fijas, sin cuerpos de respuesta, rutas, tokens o
contraseñas en logs. Cinco intentos como máximo, backoff 60/120/240/480/960 s.
Después, estado `dead`. El objeto ya inexistente se reconcilia idempotentemente.
`done` requiere confirmación de que ya no existe la metadata de Storage.
Las pruebas F01–F12 comprueban además los archivos reales del volumen local
`/mnt`; no confunden la inaccesibilidad por RLS con el borrado físico.

El cliente propietario debe desvincular una foto antes de borrarla. Las policies
DELETE impiden borrar imágenes todavía referenciadas, incluidos los avatares.
La conciliación del perfil ante respuesta perdida conserva un avatar que ya
quedó enlazado y delega estados inciertos al trabajador.

## Eliminación de cuenta

Ruta móvil: Mi perfil → Eliminar cuenta. Exige contraseña actual, aceptación de
consecuencias y escritura exacta de `ELIMINAR`. La advertencia especifica que
desaparecen todas las listas propias y sus productos, también para colaboradores.
Las listas de otros propietarios se conservan. No hay transferencia implícita.

`delete-account` limita el cuerpo a 4 KiB y cuatro campos conocidos, obtiene la
identidad del JWT validado y reautentica contra su propio correo. No acepta un
UID de destino. El RPC administrativo solo es ejecutable por `service_role`.
La sesión temporal de reautenticación se retira si la transacción es rechazada.

La transacción bloquea Auth → perfil → recetas propias → trabajos, registra una
petición duradera e idempotente, encola todos los objetos de sus dos buckets y
retira el perfil y las relaciones por sus FK/cascadas. Un upload concurrente
toma el mismo bloqueo inicial de Auth: se incluye antes de retirar la cuenta o
es rechazado después. No se busca ni borra en buckets desconocidos; un objeto
con propietario/ruta incoherente detiene la aceptación para revisión.

| Dato | Tratamiento |
|---|---|
| Perfil, recetas, ingredientes, pasos | Retirada transaccional y cascadas |
| Fotos y avatar | Cola inmediata propia; DELETE físico por trabajador |
| Likes, comentarios, guardados, seguimientos, bloqueos | Cascadas vinculadas a la identidad |
| Denuncias propias o dirigidas a su identidad/contenido | Retiradas; no conservar razones personales indefinidamente |
| Listas y productos propios | Eliminados con advertencia explícita |
| Membresías e invitaciones en listas ajenas | Eliminadas; no recuperan permisos |
| Listas/productos de otros propietarios | Conservados; sin dependencia de la receta origen |
| Ledgers, creación e importaciones auxiliares | Cascadas de sus agregados/identidad |
| Identidad Auth y refresh sessions | DELETE administrativo definitivo tras retirar archivos |
| Sesión Flutter | SignOut y borrado de almacenamiento nativo cifrado |

Tras aceptar se intenta revocar globalmente las sesiones y bloquear nuevos
inicios. Si Auth está caído, el trabajo sobrevive y se recupera. El trabajador
solo reclama Auth cuando no quedan objetos de ese propietario; confirma su
ausencia antes de marcar terminado. No existe transacción distribuida
Auth/Postgres/Storage: `202 accepted` significa aceptación duradera, no promesa
de que ya terminó el ciclo físico.

Un JWT emitido puede seguir siendo criptográficamente válido hasta su caducidad.
Por eso las 16 tablas públicas y Storage incorporan policy restrictiva de cuenta
activa; los helpers privilegiados también verifican existencia/no eliminación.
La prueba conserva el JWT antiguo e intenta leer/escribir/recrear perfil:
permanece denegado. No se afirma que el borrado invalide mágicamente el JWT.
[Limitación documentada por Supabase](https://supabase.com/docs/guides/auth/managing-user-data).

`own_account_deletion(request_id)` devuelve solo el estado mínimo de la petición
del UID del JWT. Sirve para conciliar una respuesta perdida sin reautenticar una
cuenta ya retirada; no permite consultar otro UID. La página conserva el mismo
request ID al reintentar y descarta respuestas tardías si cambia la cuenta.

## Retención e incidentes

Las trazas completadas de archivos y cuentas duran 30 días desde finalización.
Al terminar una cuenta se retira `actor_id`: queda hash SHA-256 del UUID y request
ID, estado/fechas, para conciliación e idempotencia. Es seudonimización, no
anonimización. La cola de archivos completados aún contiene la ruta hasta su
purga. Acceso exclusivo servidor. Denuncias y actuaciones de moderación se
purgan a los 30 días; al borrar la identidad se minimizan los IDs de destino y
las FK del operador se ponen a null cuando corresponde.

Los trabajos fallidos con archivo pendiente NO se purgan silenciosamente:
ocultarlos dejaría datos sin borrar. Esta es una incidencia de eliminación
incompleta, nunca un resultado de borrado completo. Política operativa propuesta:
alerta al primer `dead`, revisión en 24 h, resolución/reintento documentado dentro
de 7 días; cualquier exceso bloquea la distribución/operación hasta resolverlo.
No hay personal, alertas remotas ni SLA contratado verificados. La retención de
backups, CDN y copias exportadas requiere política remota específica antes del
lanzamiento; los tests locales no certifican su purga.

Antes de reencolar, un operador autorizado inspecciona el ID exacto, causa y
propietario, corrige la incidencia y conserva evidencia fuera de los logs móviles.
Ejemplo de intervención SQL, **plantilla que no debe ejecutarse sin un ID revisado**:

```sql
begin;
select id,state,error_code,attempts,fenced
from private.storage_cleanup_jobs where id = :job_id for update;
-- Solo tras resolver Storage, validar propietario/ruta y confirmar que sigue
-- sin referencias. No liberar fenced ni cambiar bucket/ruta/owner.
update private.storage_cleanup_jobs
set state='queued',attempts=0,not_before=clock_timestamp()
where id=:job_id and state='dead' and error_code='storage_failure';
commit;
```

La prueba F10 usa esta recuperación exclusivamente en su fixture después de una
caída real del contenedor Storage. Un `dead` por referencia/propietario manipulado
requiere investigación; no se reencola automáticamente.

## Programación preparada, sin desplegar

Local: iniciar stack con `scripts/start_isolated_supabase.ps1`, después
`scripts/serve_release_functions.ps1`; el secreto aleatorio queda en `.tooling`
ignorado. `scripts/invoke_local_worker.py` es una herramienta del host de pruebas,
no forma parte de Flutter ni de la autorización del usuario.

Remoto: configurar secretos servidor y dedicado en Vault/entorno Edge, desplegar
tras autorización, programar llamada cada minuto mediante pg_cron/pg_net, activar
alerta de HTTP fallido/cola antigua/dead y verificar F/D con cuentas de pruebas.
No poner secreto literal en migraciones, argumentos, Flutter, informes o Git.
El job remoto, Vault, cron, frecuencia efectiva, límites de runtime y alertas están
NOT_RUN. [Patrón oficial](https://supabase.com/docs/guides/functions/schedule-functions).

## Moderación mínima operativa

`private.moderation_operators` contiene identidades asignadas por un administrador
de confianza mediante SQL controlado, nunca `user_metadata` editable. El operador
usa su JWT de usuario y la clave pública, sin clave administrativa. La herramienta
`scripts/moderation_cli.py` admite listado paginado (máximo 50), revisión/cierre,
ocultar/restaurar receta, retirar comentario y restringir/restaurar perfil.
Variables del proceso: `MIXTICK_OPS_URL`, `MIXTICK_OPS_PUBLIC_KEY`,
`MIXTICK_OPS_ACCESS_TOKEN`. No pasar tokens por argumentos. Remoto exige además
autorización y `--allow-remote`; durante esta fase no se utilizó.

El servidor deriva operador del JWT y destino de la denuncia, aplica control de
versión por estado y registra cada acción. No admite un UID de destino arbitrario.
No devuelve correo/identidad de quien denuncia ni títulos/pasos privados: el
preview es público o se omite. No hay quinto módulo móvil. Ocultar impide la
republicación por el autor hasta restauración; restaurar no publica automáticamente.
Restringir perfil retira publicaciones y deniega nueva publicación/comentarios.
Cuotas históricas: comentarios 20/min y denuncias 5/min, aplicadas en base de datos.

Se requiere antes de distribución: responsables identificados, turnos, contacto
de soporte publicado, normas, plazos y recurso/revisión de decisiones. Tener RPC
y consola probadas no equivale a tener ese equipo operativo.

## Compilación local y límites de distribución

Flutter 3.47.7 / Dart 3.13.5; `pubspec.lock` preservado. Configuraciones locales
solo en `.tooling`, nunca en el APK público. El modo release rechaza HTTP, flags
de backend local, IP literales, localhost y dominios `.local`; valida sintaxis,
no conectividad ni seguridad de un proyecto remoto.

`flutter build apk --debug` genera la validación local; `flutter build apk --release`
prepara un artefacto sin firma de distribución. La configuración release ya no
reutiliza automáticamente la firma debug. No se han leído/usado claves reales.
Una compilación sin configuración muestra el estado de configuración pendiente;
no es una build conectada ni lista para usuarios finales.

Identificadores invariables: `mixtick`, organización `es.sergiotech`, Android
applicationId/namespace e iOS bundle `es.sergiotech.mixtick`. Versión de trabajo
0.1.0+1. Se conservan iconos provisionales: falta identidad gráfica final e icono
adaptativo revisado. Android: INTERNET, backup desactivado, picker sin permisos
generales de archivos; cleartext local exclusivamente en manifest debug.
Callback exacto `es.sergiotech.mixtick://auth/callback`, validado por la app.
iOS: inspección de fuente únicamente; revisar excepción de red local y recursos
con Xcode antes de crear distribución. No se declara compilación iOS desde Windows.

Google Play exige recurso web funcional de eliminación además del flujo en app;
no existe URL pública verificada en esta fase.
[Requisito oficial](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN).
Preparar privacidad, Data Safety, retención/backups y contacto; son decisiones y
servicios pendientes, no documentos legales certificados. Apple requiere
eliminación de cuenta iniciable en app; falta verificarla en iOS.
[Referencia oficial](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/).
