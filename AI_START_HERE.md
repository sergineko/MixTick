# PRIMER ARCHIVO QUE DEBES LEER SI ERES UNA IA DE PROGRAMACIÓN

Eres responsable de implementar un producto definido, **no de rediseñar su alcance**. Antes de crear o modificar archivos:

1. Lee en este orden: `AGENTS.md`, `config/product.yaml`, `docs/13_PACKAGE_IDENTIFIERS.md`, `docs/01_PRODUCT_SCOPE.md`, `docs/10_DECISIONS.md`, `docs/03_TECH_ARCHITECTURE.md`, `docs/04_DATA_MODEL.md`, `docs/05_SECURITY_PRIVACY.md`.
2. Lee también el documento específico de la fase autorizada y `docs/08_ACCEPTANCE_TESTS.md`.
3. Si el proyecto aún no existe, ejecuta exclusivamente `prompts/01_FOUNDATION.md` con `prompts/00_MASTER.md`. Para el primer mensaje listo para copiar consulta `PROMPT_DE_ARRANQUE.md`. Crea Flutter con `--org es.sergiotech --project-name mixtick`.
4. Al terminar cada fase, presenta evidencia de comandos ejecutados, pruebas, archivos modificados, migraciones, riesgos y bloqueos. Detente.
5. Si una restricción entra en conflicto con la documentación, respeta por prioridad: mensaje explícito más reciente del dueño > `config/product.yaml` + `docs/10_DECISIONS.md` > `docs/01_PRODUCT_SCOPE.md` > fase actual > sugerencias de librerías.
6. En caso de incertidumbre no bloqueante, elige la solución de menor complejidad y registra la decisión; si afecta privacidad o rompe alcance, detente antes de habilitarla.

**Regla de oro:** app sencilla y real con cuatro pestañas: Comunidad, Mi recetario, ¿Qué cocino hoy?, Lista de compra. No implementar despensa, planificación, IA generativa ni pagos.

**Contrato de identidad:** `es.sergiotech.mixtick` tanto para Android como para iOS. Comprobarlo con `scripts/check_identifiers.py` al crear el esqueleto Flutter. Para instrucciones dirigidas al propietario, consultar `INSTRUCCIONES_DE_INICIO.md`.
