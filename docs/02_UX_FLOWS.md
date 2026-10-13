# UX y pantallas

## Navegación principal (barra inferior de 4 pestañas)

1. Comunidad (`/community`): feed -> buscar -> receta pública -> perfil autor -> seguir/guardar/comentar/denunciar.
2. Mi recetario (`/recipes`): Creadas / Guardadas -> crear/editar receta -> privado/publicar -> detalle.
3. ¿Qué cocino hoy? (`/cook-today`): buscador ingredientes -> chips -> resultados exactos / faltan 1-2 -> detalle -> comprar faltantes.
4. Lista de compra (`/shopping`): listas -> detalle con pendientes/comprados -> editar ítems / invitar / solicitudes.

El acceso de perfil y ajustes será un icono en cabecera, no una quinta pestaña.

## Pantallas mínimas

- Splash/estado de sesión; Acceso; Registro; Recuperación.
- Comunidad: feed, buscador/filtros y detalle compartido de receta.
- Mi recetario: creadas/guardadas, editor, detalle compartido de receta.
- ¿Qué cocino hoy?: selector, resultados y enlace al detalle.
- Lista de compra: listado, detalle colaborativo, invitaciones pendientes y gestión de miembros.
- Perfil propio, perfil ajeno público, ajustes + eliminación de cuenta.

## Flujos imprescindibles

A. Crear privada -> verla solo yo -> publicar explícitamente -> aparece en feed -> volver a privada -> desaparece para tercero.
B. Desde una receta pública guardada, añadir ingredientes a lista compartida -> otro miembro ve ítems nuevos.
C. Elegir huevos+patatas+aceite -> resultados exactos; permitir «faltan hasta dos» -> mandar faltantes a lista.
D. Crear lista -> invitar mediante username -> receptor acepta -> ambos editan -> revocar -> ya no lee ni escribe.
E. Denunciar receta/comentario o bloquear autor, con confirmación y feedback.

## Criterios visuales

- Diseño mobile first, limpio, fotos protagonistas donde existan, tarjetas legibles, CTA prominentes.
- Componentes: RecipeCard, IngredientChip, RecipeEditorSection, ShoppingItemRow, EmptyState, ErrorState, Skeleton, ConfirmationDialog.
- Nunca sustituir un error de red por un estado vacío silencioso.
- Botón de añadir ingredientes muestra resumen editable y «Confirmar» antes de guardar.
- Etiqueta de privacidad siempre visible en edición; privada = opción inicial.

## Copys clave

- `Tu receta es privada. Solo tú puedes verla.`
- `Publicar receta` / `Hacer privada`.
- `Coincide por ingredientes. No se comprueban cantidades disponibles.`
- `Te faltan 2 ingredientes` / `Añadir a lista`.
- `Invitación enviada` / `Aceptar invitación`.
