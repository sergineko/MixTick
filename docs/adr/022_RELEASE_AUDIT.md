# ADR-022 — Auditoría y cierre técnico local

Fecha: 2026-10-14. Autorización exclusiva de Fase 08. Implementación/pruebas
local; no declara preparada la distribución.

## Matching: coste de autorización repetida

El benchmark original se reproduce sin editar 001–011 ni su script. Fixtures:
6.000 recetas, 18.000 líneas, 6.000 pasos, tres usuarios SQL temporales,
rol authenticated/UID B, RLS activa y rollback. No es signup GoTrue.
Antes: 30 muestras por modo y dos calentamientos separados. Medianas:
exact 1.793,397 ms; near 1.969,7035 ms; next 1.819,411 ms.
Los planes internos muestran 175.415–194.537 buffer hits, autorización por
línea y hasta 5.200 búsquedas repetidas de sus componentes.

012 mantiene íntegro `cook_today_page`. Las policies de recetas/perfiles usan
columnas de la fila y un conjunto de bloqueos simétricos calculado por sentencia.
Las relaciones consultan los IDs de la cabecera bajo RLS, permitiendo un
semijoin/hash en lugar de invocar el helper privilegiado por cada ingrediente.
No se desactiva RLS ni se materializan/copian recetas o selecciones de presencia.

El nuevo definer es exclusivamente un helper de permisos: deriva Auth UID,
devuelve solo IDs del conjunto de bloqueos que afecta a ese actor, tiene
search_path vacío y EXECUTE solo authenticated; `private` no se expone por API.
No acepta una identidad proporcionada por el cliente y no devuelve recetas,
campos de perfiles, razones ni datos Auth. La rama propia conserva el acceso
a privadas propias. El conjunto incluye ambas direcciones del bloqueo.
El callable SQL en el esquema privado requiere esa capacidad para evaluar RLS;
no se convierte en RPC pública. Anon no obtiene permiso de ejecución.

Validación: las mismas fixtures y 30 muestras por modo, resultados normalizados
idénticos; después de 015 las medianas son 123,6365/138,94/121,0265 ms y p95
131,979/143,092/125,869 ms. Reducción de mediana 92,946–93,348 %. Contratos y
pruebas A/B/C reales conservan relaciones privadas, bloqueos y guardados.
El coste añadido de cuenta activa/moderación se incluye en esa medición final.

## Worker: barrera duradera en lugar de un check aislado

013 extiende la cola existente. Una comprobación seguida de DELETE de Storage
sin coordinación podría borrar una foto reenlazada durante el intervalo. Se
elige bloqueo compartido entre escritores y reclamación, ruta inmutable tras
claim, lease con UUID, SKIP LOCKED, cinco intentos y deadletter visible. No se
libera fenced tras fallo. El borrado físico usa la API de Storage; no SQL de
metadata. Gracia 24 h, salvo consentimiento explícito de borrado de cuenta.

## Cuenta: retirada transaccional y recuperación interservicios

014 retira datos del producto en una transacción y conserva un trabajo servidor
que coordina Storage antes de Auth. No hay transacción distribuida entre ellos.
Se escoge borrar las listas propias completas con advertencia previa; se
preservan las ajenas. Locks Auth → perfil → recetas → jobs cierran subida
concurrente y evitan invertir el orden de los escritores de referencias.

Un JWT válido anterior no acredita cuenta activa: una policy restrictiva y los
helpers privilegiados verifican existencia/no retirada. La consulta de estado
solo acepta request ID del propio UID/hash para conciliar respuestas perdidas.
Trazas completadas 30 días, seudonimizadas; trabajo fallido no es eliminación
completa y requiere incidente operativo, nunca purga silenciosa del pendiente.

## Moderación y límites del cliente

015 añade asignación privada de operadores, acciones sobre denuncias con estado
esperado y auditoría; preview exclusivamente público, sin identidad del denunciante.
Una consola del host usa JWT de operador y clave pública. No hay nuevo tab móvil,
metadata de usuario como rol ni clave servidor en Flutter. La dotación humana
de moderación es un requisito de lanzamiento separado de estas herramientas.

La UI de eliminación es transversal, localizable y descarta respuestas tras
cambio de UID. Se conserva la arquitectura modular de los cuatro módulos.
Release deja de usar firma debug automáticamente y rechaza configuración local.
Los recursos de marca, firma real, iOS y servicios remotos siguen pendientes.

Contrato y recuperación: [operaciones](../21_RELEASE_OPERATIONS.md).
Evidencia y veredictos: [informe Fase08](../reports/PHASE_08_REPORT.md).
