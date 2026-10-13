# Autenticación y perfiles — contrato de Fase 03

La implementación utiliza `prompts/03_AUTH_PROFILE.md`. Las cuatro pestañas
continúan con sus pantallas Foundation: no se implementa negocio de Fase 04.
Auth y perfiles son soporte transversal.

## Contrato real

Supabase Auth registra/confirma credenciales y emite la sesión. `profiles` no
se crea por un trigger de Auth ni por metadatos de signup. Después de entrar,
el usuario completa su nombre visible y username desde Mi perfil. El INSERT
omite `user_id`: PostgreSQL usa `auth.uid()` y RLS impide suplantaciones.

Columnas existentes: `user_id`, `username`, `display_name`, `avatar_path`,
`created_at`, `updated_at`, `version`. El username se recorta y convierte a
minúsculas; admite solo `[a-z0-9_]{3,30}`. No se eliminan acentos para crear
equivalencias. El nombre visible admite 1–60 puntos de código tras recortar.
La unicidad pertenece al índice SQL, también bajo concurrencia.

Editar compara `user_id` de la sesión y `version` anterior. Cero filas afectadas
significa conflicto; se pide recargar. Se conserva respuesta JSON en array:
`maybeSingle()` de postgrest 2.9.1 en mutaciones puede ocultar SQLSTATE 23505/los
detalles de cero filas tras HTTP 409/406. No se alteraron las seis migraciones
históricas para corregir este problema del cliente.

El DTO público solicita únicamente `username,display_name,avatar_path`. La
interfaz no muestra email, UUID Auth, timestamps, versión ni metadatos de Auth.
El UUID de autor ya forma parte del contrato de relaciones de Fase 02; no es
un token ni un identificador de sesión. La tabla no contiene email ni datos
privados de Auth, y conserva su política de lectura autenticada con bloqueos.
La proyección mínima de cliente no sustituye la seguridad del servidor.

## Sesión y operaciones

`AuthRepository` de Foundation se amplía con registro, acceso, salida,
reenvío de confirmación, recuperación, actualización, validación y callback.
`authSessionProvider` centraliza identidad; los widgets llaman a controladores
Riverpod/repositorios y nunca a Supabase. Las operaciones Auth se serializan y
los formularios deshabilitan envíos repetidos. Los errores de dominio se
traducen con ARB; no se muestran excepciones originales ni se registran tokens.

El SDK persiste la sesión y el verificador PKCE mediante adaptadores de
`flutter_secure_storage`, en un namespace por host/puerto de backend.
Android usa los cifrados de la versión fijada; los backups de la app están
deshabilitados. iOS configura Keychain `first_unlock_this_device`. iOS requiere
verificación nativa en macOS: la configuración de fuente no equivale a prueba.
La salida espera la eliminación local de la sesión incluso si falla el logout
de red; no promete revocación instantánea de JWT ya emitidos por otros clientes.

La restauración valida/renueva la sesión en servidor antes de abrir rutas
privadas. También se valida al volver a primer plano y cada minuto mientras
la app está activa. El SDK mantiene renovación automática y descarta resultados
de refresh anteriores a cambios de sesión. Un fallo inicial no cierra para
siempre el stream: un nuevo acceso real puede recuperarlo. Los datos/formularios
se descartan al cambiar de cuenta; un refresh del mismo usuario conserva el
borrador del perfil. La autoridad de acceso sigue en RLS.

`BoundedHttpClient` aborta la solicitud real tras 15 s por intento, incluso
durante lectura del cuerpo. No se libera la operación Auth dejando una respuesta
tardía capaz de sustituir una sesión posterior. Los reintentos del SDK pueden
prolongar la operación; no se promete que toda operación termine en 15 s.
Se preservan los headers generados al finalizar multipart para subidas Storage.

## Correo y enlaces

La configuración local conserva `enable_confirmations=false` de Fase 02.
El cliente interpreta `session == null` como confirmación requerida y ofrece
reenvío. No muestra «ese correo existe»: registro duplicado y recuperación
usan mensajes genéricos. La política concreta de enumeración, entrega de correo
y contraseña pertenece también al proyecto Auth; no se afirma que el UI cambie
las respuestas de una API remota. El mínimo local sube a 8 caracteres.

PKCE utiliza exclusivamente `es.sergiotech.mixtick://auth/callback`, añadido
a `additional_redirect_urls` local. Android registra scheme/host/path exactos;
iOS registra el scheme y la validación Dart exige host/path exactos. Se desactiva
el procesamiento paralelo de enlaces de Flutter/Supabase: `app_links` entrega
el enlace al repositorio una sola vez. Se rechazan destinos alternativos,
fragmentos con tokens, parámetros duplicados y retornos sin un único `code`.
El intercambio necesita el verificador del dispositivo que solicitó el correo.
El código y la URI no se registran.

`passwordRecovery` persiste un marcador asociado al UUID del usuario. Las
pestañas quedan bloqueadas hasta guardar la nueva contraseña o salir. Un enlace
inválido/caducado abre una pantalla de error comprensible, también si ya había
otra sesión. Los callbacks esperan operaciones anteriores para evitar perderse
al coincidir con una revalidación.

Una futura configuración remota debe permitir exactamente el mismo retorno,
activar confirmación si corresponde y configurar su envío de correo. No se ha
modificado ni conectado ningún proyecto remoto. PKCE y sesiones siguen las
[guías oficiales de Supabase](https://supabase.com/docs/guides/auth/sessions/pkce-flow)
y [enlaces móviles](https://supabase.com/docs/guides/auth/native-mobile-deep-linking?platform=flutter).

## Foto opcional

La migración nueva `20261013000700_profile_avatars.sql` añade el bucket privado
`profile-avatars`, 2 MiB, JPEG/PNG/WebP, sin modificar `recipe-photos`. Rutas:
`<user_id>/<uuid>.jpg|png|webp`. Solo el propietario con perfil creado escribe;
otros autenticados sin bloqueo leen únicamente la foto actualmente referenciada.
Anon no lee. La referencia debe ser propia y existir en Storage con ese owner.

La interfaz permite seleccionar, cambiar y quitar foto tras guardar el perfil.
La foto se decodifica fuera de la UI, se limita a 1024 px y 16 millones de
píxeles de entrada, y se copia a RGB nuevo/reencodifica como JPEG sin metadatos
de origen. Los PNG transparentes se componen sobre blanco. El límite final es
2 MiB. Este procesamiento corresponde al cliente Flutter: no se afirma que
Storage transcodifique subidas de clientes externos.

Se descarga con autorización vigente y se muestra en memoria; no se emiten
URLs firmadas desde la app. Al cambiar/quitar foto, se intenta borrar el archivo
anterior por Storage API. Fallos de borrado se comunican; SQL encola el archivo
como respaldo. El trabajador físico previo al lanzamiento sigue pendiente, al
igual que el de fotos de recetas. Fotos ya descargadas y URLs firmadas emitidas
por otros clientes no pueden retirarse retroactivamente.

## Entorno y reproducción

Solo debug/profile admite HTTP y requiere `MIXTICK_ALLOW_LOCAL_BACKEND=true`;
los destinos permitidos son localhost/127.0.0.1 o el alias de emulador Android
10.0.2.2, puerto 54321. Release exige HTTPS. Android permite cleartext local
solo en su manifest/config de debug. No hay aceptación global de certificados
ni desactivación de verificación TLS.

Usar `scripts/start_isolated_supabase.ps1` en Windows. Compila un adaptador
Docker en `.tooling` y lo añade solo al PATH del proceso CLI, imponiendo
`127.0.0.1` a cada publicación antes de crear contenedores. No modifica el
daemon, firewall ni otros proyectos. `assert_local_isolation.ps1` comprueba
Docker >=28, bindings reales, listeners Windows e intentos contra otras
interfaces. La solución se basa en [publicación de puertos de Docker](https://docs.docker.com/engine/network/port-publishing/),
no en asumir aislamiento porque una petición use localhost. Ante fallo se para
el stack. El runner de Fase 02 ahora utiliza este arranque seguro.

```powershell
.\scripts\verify_auth_profile.ps1 -BackendChecks -ResetLocal -IncludeAndroidBuild
```

`-ResetLocal` es opt-in y se limita al proyecto de fixtures `mixtick-phase02`.
El runner verifica migraciones, 25 checks SQL, regresiones API y el cliente real
con confirmación desactivada/activada. La alternancia es temporal, solo local;
restaura config y para el stack en `finally`. Luego ejecuta calidad Flutter/IDs.
Configuración pública temporal en `.tooling` queda ignorada.

Con emulador ya iniciado y backend aislado en auto-confirm local:

```powershell
.\scripts\start_isolated_supabase.ps1
.\scripts\verify_native_auth.ps1 -Device emulator-5554
.\.tooling\supabase\supabase.exe stop --project-id mixtick-phase02
```

Las dos pruebas Android ejecutan APKs en procesos independientes. Es obligatorio
`--no-uninstall`: el runner Flutter desinstala por defecto al terminar y borra
los datos antes del segundo arranque. El ayudante entrega el callback real del
correo Mailpit mediante ACTION_VIEW sin imprimirlo. Las fixtures se retiran por
sus UUID devueltos; no se utilizan cuentas ni credenciales de otros entornos.

Tests de UI con `FakeAuthRepository/FakeProfileRepository` se identifican como
mocks. El cliente local usa Auth/API/Storage reales y un adaptador PKCE en memoria;
solo un caso híbrido inyecta una interrupción de transporte. Android verifica
almacenamiento nativo. Ninguna de estas pruebas demuestra comportamiento de
un proveedor de correo remoto, CDN, dispositivos iOS o Realtime colaborativo.
