# ADR-017 — Auth real, perfil mínimo y retorno PKCE

Fecha: 2026-10-13. Alcance: exclusivamente Fase 03 autorizada.

Se amplía el repositorio Foundation, conservando módulos, stack e identificadores.
Riverpod controla sesión/operaciones y GoRouter protege las cuatro pestañas.
El alta Auth y la elección posterior de username son pasos separados: no se
inventan RPC ni se usan email/metadatos para generar un perfil público.

La sesión/verificador se guardan en almacenamiento seguro por backend; PKCE
admite un único retorno nativo validado. El estado de recuperación pertenece al
usuario y bloquea las pestañas hasta actualizar contraseña/salir. Se serializan
Auth/callbacks y se abortan solicitudes en vez de dejar respuestas tardías.
Se mantienen streams recuperables tras fallos de conexión y se descartan
borradores/datos al cambiar de cuenta.

El índice SQL decide la unicidad. Edición optimista por versión y respuesta en
array preservan errores reales de PostgREST; no se modifican las seis migraciones
aceptadas. El DTO público omite email/metadatos/UUID/versión. Sigue siendo RLS
la autoridad; la proyección de cliente no se presenta como control de seguridad.

Solo la migración 007 añade lo que falta: bucket privado de avatares, vínculo
propio/existente y cola de limpieza. El cliente reencodifica fotos sin metadatos
y usa descarga autenticada. El trabajador físico y distribución siguen fuera
de alcance, pendientes antes del lanzamiento.

La CLI 2.120.0 publica puertos sin dirección en su comando Docker. Un adaptador
de PATH exclusivo de ese proceso añade loopback antes de crear contenedores;
se comprueban bindings/listeners/probes y se para el stack tras las pruebas.
No se relaja un firewall ni se altera Docker global. La verificación nativa
conserva la app con --no-uninstall entre procesos; los mocks de UI y el caso
híbrido de conectividad se distinguen de Auth/RLS/Storage reales.

Detalles/reproducción: [contrato Auth/perfiles](../16_AUTH_PROFILE.md).
