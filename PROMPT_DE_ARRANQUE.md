# PRIMER MENSAJE PARA LA IA — copiar íntegro

Quiero que desarrolles conmigo la app **MixTick** (Android e iOS) con Flutter, siguiendo estrictamente los archivos ya incluidos en la carpeta de proyecto.

**Primero** inspecciona el repositorio y lee, en este orden:
1. `AI_START_HERE.md`
2. `AGENTS.md`
3. `config/product.yaml`
4. `docs/13_PACKAGE_IDENTIFIERS.md`
5. `docs/01_PRODUCT_SCOPE.md`
6. `docs/10_DECISIONS.md`
7. `docs/03_TECH_ARCHITECTURE.md`
8. `docs/04_DATA_MODEL.md`
9. `docs/05_SECURITY_PRIVACY.md`
10. `docs/08_ACCEPTANCE_TESTS.md`
11. `prompts/00_MASTER.md`
12. `prompts/01_FOUNDATION.md`

## Regla técnica obligatoria

**TODOS los identificadores de esta aplicación siguen Sergiotech:**
- Flutter project name / pubspec: `mixtick`
- Organización: `es.sergiotech`
- Android applicationId y namespace: `es.sergiotech.mixtick`
- Android MainActivity package: `es.sergiotech.mixtick`
- iOS Runner Bundle Identifier: `es.sergiotech.mixtick`

Nunca crees identificadores `com.example`, `com.mixtick` ni equivalentes. El nombre comercial y el identificador técnico son cosas distintas.

## Autorización de trabajo

Te autorizo **SOLO LA FASE 01 — FOUNDATION** de `prompts/01_FOUNDATION.md`. Implementa realmente lo que pide en el repositorio, sin avanzar a la siguiente fase. Si Flutter aún no está inicializado y tu entorno lo permite, ejecútalo en esta misma raíz con:

`flutter create --org es.sergiotech --project-name mixtick --platforms=android,ios .`

Respeta exactamente **cuatro módulos funcionales**: Comunidad, Mi recetario, ¿Qué cocino hoy? y Lista de compra. No implementes despensa, planificador, IA generativa ni pagos.

Si falta una herramienta, dependencia o credencial, documenta el bloqueo y sigue con las tareas factibles de la fase. No inventes integración ni resultados.

Al terminar ejecuta lo que permita el entorno: `dart format`, `flutter analyze`, `flutter test`, y `py -3 scripts/check_identifiers.py --strict` (alternativa `python`). Entrega informe basado en `templates/PHASE_REPORT.md` con archivos modificados, comandos, resultados, pruebas PASS/FAIL/NOT_RUN, riesgos y próximo paso. Actualiza `docs/PROGRESS.md`.

**No hagas commits, push, despliegues o llamadas remotas que modifiquen servicios sin mi autorización; no pases de fase automáticamente.**
