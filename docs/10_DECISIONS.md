# Registro de decisiones aprobadas (inicial)

- **ADR-001 / Alcance:** cuatro módulos cerrados: Comunidad, Mi recetario, ¿Qué cocino hoy? y Lista de compra. No sumar otros.
- **ADR-002 / Stack:** Flutter + Supabase, Riverpod y GoRouter, salvo incompatibilidad fundamentada.
- **ADR-003 / Privacidad:** receta nueva privada por defecto; publicar requiere acción explícita.
- **ADR-004 / Ingredientes:** catálogo y alias para normalización; texto libre acotado como fallback.
- **ADR-005 / ¿Qué cocino?:** selección efímera sin despensa, cantidad de ingrediente no contrastada con lo que hay en casa.
- **ADR-006 / Compra:** dueño y colaboradores con aceptación explícita, sincronización con Realtime.
- **ADR-007 / Social:** feed cronológico, guardar referencias y controles UGC mínimos.
- **ADR-008 / Nombre:** `MixTick` es un working title; no consolidar hasta clearance.
- **ADR-009 / Idioma:** interfaz inicial en español, preparada para localización futura.
- **ADR-010 / Desarrollo:** fases secuenciales aprobadas individualmente, sin deploy/commit/push automáticos.
- **ADR-011 / Autenticación:** se exige registro/login para las cuatro pestañas del MVP; acceso público web no incluido.
- **ADR-012 / Listas:** invitaciones por username de una cuenta ya registrada; sin enlaces profundos de invitación.
- **ADR-013 / Cantidades:** cantidades de receta y compra se guardan, pero no inventariar cantidades disponibles en casa.

Ningún prompt debe contradecir estas decisiones sin aprobación expresa del propietario.

- **ADR-014 / Identificador técnico obligatorio:** prefijo global Sergiotech `es.sergiotech.`; para MixTick: Android `applicationId`/`namespace` e iOS bundle ID = `es.sergiotech.mixtick`. Proyecto Flutter `mixtick` y organización `es.sergiotech`. Esta regla prevalece sobre placeholders, plantillas o ejemplos de Flutter. No renombrar los identificadores tras la creación sin decisión explícita del propietario.

- **ADR-015 / Foundation:** entorno estable verificado, navegación protegida de cuatro pestañas, cliente Supabase opcional con configuración pública, localización `es_ES` y pruebas reproducibles. Alcance y limitaciones en [ADR-015](adr/015_FOUNDATION.md).
