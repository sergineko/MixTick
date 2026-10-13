# Algoritmo para «¿Qué cocino hoy?» (sin IA)

## Entradas

- `selected_ingredient_ids`: set de IDs canónicos escogidos por el usuario.
- `selected_free_text_keys`: set de nombres libres normalizados.
- `mode`: `exact` o `near`.
- `accessible_recipes`: publicaciones + recetas privadas propias, deduplicadas por `recipe.id` y sujetas a permisos reales.

## Cálculo

1. Obtener los ingredientes obligatorios de cada receta (`optional=false`).
2. Para un ingrediente de catálogo, comparar su `ingredient_id` con `selected_ingredient_ids` (alias deben resolverse a ese ID antes del cálculo).
3. Para un ingrediente libre, comparar su clave de texto normalizado con `selected_free_text_keys`.
4. `missing = required - selected`.
5. Modo `exact`: `missing_count == 0`; modo `near`: `1 <= missing_count <= 2`, pudiendo presentar coincidencias exactas también en una sección separada.
6. Ordenar: exactas primero, luego menor número de faltantes, después menor tiempo total, después publicación reciente/ID para estabilidad.
7. Ingredientes opcionales nunca descalifican coincidencia.
8. Mostrar aviso: «Las cantidades disponibles no se comprueban».

## Restricciones

- No inferir equivalencia entre productos diferentes (p.ej. crema y leche).
- No asumir que «aceite», «sal» o «agua» están disponibles si no se seleccionan. Una opción de atajos de básicos puede preseleccionar, pero no inferir silenciosamente.
- No mostrar recetas ajenas privadas aunque el ID sea conocido. No usar likes/saves como bypass de privacidad.
- No crear ni persistir despensa, caducidades o inventario.
- Si no hay ingredientes seleccionados, mostrar mensaje de estado vacío sin pedir consulta pesada.

## Casos de prueba

- {huevo, patata} requerido y selección {huevo, patata, cebolla}: exacto.
- {huevo, patata, cebolla} requerido y selección {huevo, patata}: near con 1 faltante.
- Tomates alias -> tomate ID igual: exacto.
- Ingrediente opcional ausente: no cuenta como faltante.
- Misma receta vista por feed y guardados: una tarjeta, no dos.
- Receta ajena privada: nunca se recupera.
