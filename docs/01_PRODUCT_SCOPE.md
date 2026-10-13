# Alcance funcional del MVP v1.0

## Propuesta de valor

«Descubre o crea una receta; indica lo que tienes; añade lo que falta a una lista que compras con otras personas». Cuatro pestañas, un mismo modelo de receta e ingrediente, experiencias conectadas.

## 1. Comunidad

- Feed cronológico paginado de recetas publicadas (sin recomendador algorítmico).
- Buscar por título, categoría, ingrediente reconocido; entrar al detalle del autor.
- Ver receta, dar/quitar me gusta, guardar/quitar guardado, comentar, borrar comentario propio.
- Seguir/dejar de seguir autores; visualizar su perfil público y recetas públicas.
- Denunciar contenido y bloquear cuentas para seguridad básica (funciones transversales obligatorias).
- Solo contenido PUBLICO visible a otros; feed y búsquedas deben respetar bloqueos.
- El propietario controla su receta; nadie puede editar la de otro.

## 2. Mi recetario

- Dos apartados: «Creadas por mí» y «Guardadas»; guardar no copia la receta.
- Crear, editar, archivar no: eliminar con confirmación, publicar y retirar publicación.
- Por defecto `visibility=private` y botón de publicación explícito.
- Una receta tiene: título, descripción opcional, foto principal opcional, categoría, raciones (>0), tiempo opcional, ingredientes (al menos 1) y pasos ordenados (al menos 1). Un ingrediente tiene nombre (catálogo o texto libre), cantidad opcional, unidad opcional y marca de opcional.
- Tras despublicar una receta, desaparecerá de accesos ajenos y de guardados visibles. Pueden persistir marcadores invisibles para conservar integridad, pero jamás debe filtrarse información privada.

## 3. ¿Qué cocino hoy?

- El usuario elige ingredientes manualmente en la sesión (chips + autocompletado); no se crea inventario permanente.
- Buscar entre recetas propias (privadas incluidas) y recetas públicas (guardadas o no); deduplicar.
- Coincidencia completa si TODOS los ingredientes obligatorios están disponibles en la selección, ignorando los opcionales.
- Alternativa «Faltan hasta dos» ordenada por número de ingredientes obligatorios no seleccionados (1 primero, 2 segundo).
- **NO** afirmar que el usuario puede cocinar una receta si la cantidad disponible es insuficiente: no se registran cantidades de la despensa. Mostrar «Coincide por ingredientes (cantidades no comprobadas)».
- CTA: «Añadir ingredientes faltantes a mi lista»; la selección de lista y confirmación se implementa en módulo de compra.

## 4. Lista de compra

- Cada usuario puede crear varias listas, renombrar, borrar las propias y ver las compartidas.
- CRUD de ítems: nombre, cantidad/unidad opcionales, marcado comprado, editado, borrado. Estado pendiente/comprado.
- Propietario invita a usuarios ya registrados por nombre público único; destinatario acepta o rechaza; propietario revoca. Los invitados no pueden invitar a otros ni eliminar la lista.
- Miembros autorizados pueden modificar productos y ver cambios sincronizados en tiempo real; la operación debe persistir aunque falle la conexión Realtime y sincronizarse al volver.
- Desde una receta accesible, elegir lista e importar TODOS o ingredientes seleccionados (no duplicar accidentalmente por reintento). Desde ¿Qué cocino hoy?, importar solo ingredientes faltantes.
- Copiar una lista de ingredientes no transmite a otros títulos, notas, enlaces ni identificadores de recetas privadas.

## Funciones transversales permitidas

Registro, confirmación de correo si corresponde, login, recuperación contraseña, sesión, perfil editable, ajustes mínimos (idioma futuro, cerrar sesión, eliminar cuenta), denuncia/bloqueo de contenido y usuarios, gestión básica de solicitudes. No generar un quinto módulo visible.

## Fuera del alcance (estricto)

Despensa, inventario persistente, control de existencias, caducidades, planificador semanal, recetas generadas por IA, reconocimiento automático de fotos, chat, vídeos, live, monetización, compras en supermercados, precios, geolocalización, analítica nutricional, rankings de chefs, retos, sincronización offline-first completa.

## Requisitos no funcionales

- Arranque y navegación fluidos en gama media; imágenes optimizadas, listas paginadas.
- Operaciones repetibles e idempotentes cuando importan varios ingredientes; consistencia de creación/edición.
- Accesibilidad: etiquetas semánticas, contraste, fuente escalable; español inicial localizable.
- Privacidad por diseño y minimización de datos; no recopilar contactos, localización ni datos de salud.
- Conexión necesaria para funcionalidades colaborativas; tratar offline con mensajes y reintentos visibles, sin prometer modo offline completo.
