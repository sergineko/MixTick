# Experiencia, E2E y Realtime — Fase 08

## Auditoría visual

Pixel_10a, un emulador Android17/API 37, captura física 1080×2424. Los cuatro
recorridos Android usan backend local real; no sustituyen repositorios/permisos.
Claro/oscuro de la plataforma, teclado y galería del sistema cuando corresponde.
Los tests320×640/200 % son widgets con repositorios controlados, identificados
como tales; no son capturas de dos teléfonos ni validación iOS.

| Módulo | Estado | Comprobaciones y evidencias |
|---|---|---|
| Comunidad | PASS | Feed/búsqueda/filtros, foto, likes, guardados, comentarios, perfil, seguir/denunciar/bloquear y retirada de privadas; [Android](community-regression/evidence/native-community.txt), [claro](community-regression/previews/community-light.png), [oscuro](community-regression/previews/community-dark.png), [guardados](community-regression/previews/saved-recipes.png) |
| Mi recetario | PASS | CRUD, ingredientes/pasos, teclado, foto, picker cancelar/elegir, privacidad, aislamiento y atrás; [Android](recipe-regression/evidence/native-recipes.txt), [editor](recipe-regression/previews/editor-gallery.png), [claro](recipe-regression/previews/detail-light.png), [oscuro](recipe-regression/previews/detail-dark.png) |
| ¿Qué cocino? | PASS | Selector/catálogo/alias, chips, duplicado, exact/near, resultado/detalle/importación sin inventario; [Android](matching-regression/evidence/native-matching.txt), [selección](matching-regression/previews/matching-selection.png), [claro](matching-regression/previews/matching-light.png), [oscuro](matching-regression/previews/matching-dark.png) |
| Compra | PASS | Lista/producto/check, cantidades, importación, invitación/miembros, otra sesión y revocación; [Android](shopping-regression/evidence/native-shopping.txt), [selección](shopping-regression/previews/shopping-selection.png), [claro](shopping-regression/previews/shopping-light.png), [oscuro](shopping-regression/previews/shopping-dark.png) |
| Cuenta transversal | PASS | Consecuencias/listas propias, consentimiento, contraseña oculta, confirmación, procesamiento/salida y sesión nativa retirada; [Android](account-native/evidence/native-account.txt), [claro](account-native/previews/account-delete-light.png), [oscuro](account-native/previews/account-delete-dark.png), [habilitado](account-native/previews/account-delete-enabled.png), [salida](account-native/previews/account-deleted-session.png) |

Se inspeccionaron capturas de los cuatro módulos. No se generaron imágenes para
simular la interfaz. Las fotografías de recetas son fixtures controladas. La
barra de navegación conserva cuatro destinos, Material3 y tema de semilla.

| Criterio transversal | Estado | Alcance |
|---|---|---|
| 320px, texto200, claro/oscuro | PASS | Suites de widgets de Auth, recetas, Comunidad, matching, compra y nueva eliminación; sin excepciones/desbordamientos |
| Estados vacíos/error/reintento | PASS | Widgets controlados de cada módulo y errores reales de API; no se afirma caída espontánea de red móvil |
| Validación/botón habilitado | PASS | Formularios y eliminación exigen campos/consentimiento; busy evita doble envío |
| Teclado, scroll, atrás | PASS | Recorridos Android y widgets, campos lazy con scroll al destino; PopScope durante procesamiento |
| Etiquetas y áreas táctiles nuevas | PASS | Guideline Android48dp y labeledTapTarget en página de eliminación, ambos temas/200 % |
| Contraste nuevo | PASS | Guideline de texto sobre pantalla estable, ambos temas/200 %; color destructivo usa `onError` |
| Semántica general | PASS | Etiquetas/tooltip/estados revisados y semántica del nuevo flujo; cobertura automática completa de todos los estados no afirmada |
| TalkBack/VoiceOver manual | NOT_RUN | No sesión asistiva con usuario ni entorno iOS |
| Certificación accesibilidad | NOT_RUN | El alcance local no equivale a certificación |

Se separó la advertencia larga sobre listas del texto del checkbox: en 320px/200 %
el centro del checkbox quedaba fuera del hit target al hacer scroll. Se conserva
la advertencia y se usa una etiqueta breve; ninguna consecuencia se elimina.
La primera medición de contraste capturó la transición disabled→enabled del botón;
se añadió espera de estabilización y se explicitó `onError`. Se corrigió además
el cierre del handle de semántica del test. Los FAIL iniciales están conservados;
no se atribuyen los errores del harness a una regresión de los cuatro módulos.

## E2E principal

[Ejecución final real](evidence/e2e-performance-final.txt). Repositorios reales,
tres clientes GoTrue, Storage, HTTP y sockets independientes desde host. Es un
recorrido integrado de contratos del producto, complementado por los recorridos
de UI Android anteriores; no se etiqueta como 23 pasos táctiles en dos móviles.

| Paso | Estado | Hecho observado |
|---:|---|---|
| 1 | PASS | Registro A/B/C en GoTrue |
| 2 | PASS | Receta de A nace privada; B conoce UUID y no la lee |
| 3 | PASS | Ingredientes, cantidades originales y foto procesada/subida/enlazada |
| 4 | PASS | Publicación explícita de A |
| 5 | PASS | B encuentra la receta original en Comunidad |
| 6 | PASS | B guarda referencia sin copiar receta |
| 7 | PASS | Consulta real de matching |
| 8 | PASS | Alias completo Huevos resuelto |
| 9 | PASS | Falta solo Patata, original0,5kg; Sal opcional no falta |
| 10 | PASS | Lista propiedad de B |
| 11 | PASS | Invitación explícita a A |
| 12 | PASS | A acepta, C sigue sin autorización |
| 13 | PASS | B importa solo faltantes mediante preview checked |
| 14 | PASS | Socket independiente A ve cambio y lee0,5kg |
| 15 | PASS | A marca comprado con versión |
| 16 | PASS | Socket independiente B y lectura confirman comprado |
| 17 | PASS | A/B escriben simultáneamente la misma versión |
| 18 | PASS | Un ganador y un conflicto explícito, sin sobrescritura silenciosa |
| 19 | PASS | B publica y privatiza receta propia; C pierde acceso UUID |
| 20 | PASS | Propietario B revoca A |
| 21 | PASS | API rechaza JWT anterior/invitación anterior de A |
| 22 | PASS | A solicita eliminación autenticada con contraseña |
| 23 | PASS | Worker real retira foto/Auth; receta A desaparece, lista B sobrevive, sesión local cierra |

El disparo del worker lo hace el host con secreto servidor. Sus efectos se
comprueban con clientes, Auth y, en F/D, el volumen físico. El teardown posterior
es administrativo, separado y no suma pasos del producto.

## Casos adicionales

| Escenario | Estado | Evidencia y naturaleza |
|---|---|---|
| Sesión caducada y refresh | PASS | Auth 13 por modo, D03/Auth borrado; backend real |
| Red y respuesta ambigua | PASS | Suite histórica conserva transportes que retienen respuestas reales; widgets de errores con mocks |
| Respuesta tardía/UID A→B | PASS | Tests controlados y casos híbridos identificados; ningún dato A reaparece en B |
| Cierre/reapertura | PASS | Dos procesos Android originales, sesión cifrada y callback de recuperación |
| Cuentas distintas mismo Android | PASS | Recorridos nativos de recetas/Comunidad/compra y logout; no dos dispositivos físicos |
| Imagen inválida/metadata/límites | PASS | Pruebas de procesador y fallo de fixture inválida conservado; nueva ejecución válida pasa |
| Datos incompletos/inexistentes | PASS | Widgets y regresiones directas de repositorios |
| Bloqueados y UUID directo | PASS | API 20, Comunidad 30, matching 23, compras16 y E2E |
| iOS | NOT_RUN | Host Windows sin Xcode/dispositivo compatible |

## Realtime

| Caso | Estado | Verificación |
|---|---|---|
| Ediciones autorizadas A/B | PASS | Dos sockets reales; add/check/cantidad/delete de producto |
| Pérdida y reconexión | PASS | Desconexión deliberada de socket real, escritura offline y relectura tras reconectar |
| Repetidos/fuera de orden | PASS | Señales y respuestas controladas prueban epochs/debounce/relectura; no se afirma emisión artificial desde servidor |
| Cambio rápido de ruta/lista | PASS | Provider dispose/cancel y widget controlado, sin canal de pantalla no visible |
| Cambio UID | PASS | Estado/transportes híbridos y UI Android con dos cuentas; Auth real en casos identificados |
| Revocación/bloqueo | PASS | API real deja de autorizar; UI Android se limpia tras revalidar |
| C/anon | PASS | WebSocket directo con UUID conocido sin eventos de productos |
| Borrado de producto | PASS | Padre tocado y lectura autorizada; no publicar DELETE con payload privado |
| Borrado de lista completa | PASS | E2E con controller y transporte reales, UID provider controlado; 14.349 ms hasta ocultar, un canal/cinco lecturas |
| Remoto/carga/dispositivo físico | NOT_VERIFIED | No se presupone igualdad con Docker/emulador |

La denegación servidor es efectiva desde el commit. La UI ya cargada puede tardar
hasta el probe visible de15s (más red/scheduler); la prueba local no fija un SLA
remoto. Las copias que alguien ya descargó no se recuperan. No hay probes por
producto ni suscripción al descubrir listas ajenas. Los tests anteriores no se
eliminaron para conseguir estos resultados.
