# ADR-020 — Comparación de presencia bajo RLS

Estado: decisión de implementación dentro de la autorización Fase 06.

Se reutilizan recetas, catálogo/alias, fotografías y detalle. La selección vive
solo en la pantalla y se descarta por identidad; no hay inventario ni cantidades
disponibles de casa. Nombres ambiguos permanecen literales hasta elegir una
opción concreta. No hay equivalencias semánticas ni IA.

010 añade una RPC invoker de lectura e índice de texto libre, conservando
001–009 y sus RLS. Comparar y ordenar en PostgreSQL evita descargar todas las
recetas al móvil; un cursor con ranking e ID limita cada respuesta. Ningún
guardado otorga acceso adicional ni se convierte en otra copia de receta.

Se excluyen selección vacía, recetas sin obligatorios y coincidencias parciales
sin un obligatorio presente. Near incluye completas diferenciadas antes de
las que faltan uno/dos. Orden exacto: opcionales coincidentes, tiempo, UUID;
near: faltantes, obligatorios coincidentes, tiempo, UUID. No hay scores arbitrarios.

Se conservan los límites de revisión de permisos e imágenes de Fase 05. Un DTO
de faltantes retiene líneas/ordinales/cantidades de receta para Fase 07, sin
realizar compras ni presentar un botón desconectado. Ver
[contrato](../19_COOK_TODAY.md) y [algoritmo](../06_MATCHING_ALGORITHM.md).

Consecuencias: las búsquedas necesitan conexión; reordenaciones concurrentes
requieren refresh. La lectura bajo RLS tiene coste real, documentado por el
benchmark local, sin prometer rendimiento remoto o revocación de copias.
Fase 07, Git, despliegue y Supabase remoto no quedan autorizados.
