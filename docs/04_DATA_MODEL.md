# Modelo de datos — especificación y esquema SQL

La especificación conceptual se conserva a continuación. La Fase 02 la implementa
en seis migraciones SQL de `supabase/migrations/`. Toda tabla de producto expuesta
y toda tabla técnica tiene RLS activada. Véase [esquema implementado](14_DATABASE_IMPLEMENTATION.md)
para columnas definitivas, RPC, grants, cascadas y límites; las migraciones son
la fuente ejecutable. La evidencia local está en el [informe de Fase 02](reports/PHASE_02_REPORT.md).

| Tabla | Campos de referencia | Restricción crucial |
|---|---|---|
| `profiles` | `user_id PK/FK auth.users`, `username`, `display_name`, `avatar_path`, `created_at` | `username` único, normalizado, no revelar email |
| `recipes` | `id`, `author_id`, `visibility`, `title`, `description`, `category`, `servings`, `prep_minutes`, `cook_minutes`, `hero_image_path`, `published_at` | `private` por defecto; author FK; `servings > 0` |
| `ingredients` | `id`, `canonical_name_es`, `normalized_key`, `approved` | `normalized_key` único |
| `ingredient_aliases` | `id`, `ingredient_id`, `normalized_alias` | `normalized_alias` único |
| `recipe_ingredients` | `id`, `recipe_id`, `ingredient_id?`, `custom_name?`, `quantity?`, `unit?`, `optional`, `sort_order` | exactamente uno: catálogo o nombre libre; cantidad positiva si indicada |
| `recipe_steps` | `id`, `recipe_id`, `sort_order`, `instruction` | orden único por receta |
| `recipe_saves` | `user_id`, `recipe_id`, `created_at` | PK compuesta sin duplicados |
| `recipe_likes` | `user_id`, `recipe_id`, `created_at` | PK compuesta |
| `recipe_comments` | `id`, `recipe_id`, `author_id`, `content`, `created_at` | longitud acotada; usuario solo edita/borra propios |
| `user_follows` | `follower_id`, `followed_id` | no autopseguirse; única combinación |
| `shopping_lists` | `id`, `owner_id`, `title`, `created_at`, `updated_at` | solo owner borra/administra miembros |
| `shopping_list_members` | `list_id`, `user_id`, `joined_at` | colaboración sin duplicados; propietario queda en `shopping_lists` |
| `shopping_list_invitations` | `id`, `list_id`, `sender_id`, `invitee_id`, `status`, `created_at` | solo dueño invita, solo receptor acepta, evitar pending duplicada |
| `shopping_items` | `id`, `list_id`, `name`, `ingredient_id?`, `quantity?`, `unit?`, `is_purchased`, `source_key?`, `updated_at` | unique `(list_id,source_key)` cuando clave disponible |
| `content_reports` | `id`, `reporter_id`, `target_type`, `target_id`, `reason`, `created_at`, `status` | denunciante no ve informes ajenos; revisión admin |
| `user_blocks` | `blocker_id`, `blocked_id`, `created_at` | unique par y no autobloqueo |

`target_type + target_id` en informes requiere validación backend porque no es FK polimórfica automática. Si la implementación añade tablas técnicas (p.ej. auditoría o idempotencia), justificarlas sin introducir módulos de usuario nuevos.

## Semántica de visibilidad

- `recipes.visibility` solo `private`/`public`; valor por defecto en la BD `private`, además del cliente.
- `published_at` solo se rellena al publicar por primera vez (si se requiere ordenar por publicación reciente tras republish, documentar regla antes de cambiarla).
- Relaciones de receta (ingredientes, pasos, comentarios, guardados, likes) deben heredar permisos de su receta; no basta RLS en tabla `recipes`.
- Al ocultar receta, guardar/like anteriores pueden permanecer como referencias internas, pero cualquier lectura ajena debe ocultarse. Definir y probar cómo aparece una referencia ahora inaccesible en favoritos.
- Foto de receta protegida por política de Storage congruente con estado de publicación y acceso (ver seguridad).

## Datos de compra

No guardar vínculos legibles para colaboradores que identifiquen recetas privadas de otro usuario. En la importación, copiar el **nombre/cantidad/unidad** al ítem. No exponer origen de receta privada.

## Catálogo y texto libre

Cargar semilla de ingredientes españoles comunes y alias (tomate/tomates, cebolla/cebollas, etc.). El editor debe permitir ingredientes fuera del catálogo con texto libre validado; dos textos libres solo coinciden si su forma normalizada es idéntica. No inventar equivalencias de ingredientes diferentes. La búsqueda avanzada podrá ampliar alias en fases futuras, no ahora.
