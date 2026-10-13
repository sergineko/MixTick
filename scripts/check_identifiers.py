#!/usr/bin/env python3
"""Verifica identificadores de MixTick tras ejecutar flutter create.

Uso: python scripts/check_identifiers.py --strict
No requiere paquetes externos. No modifica ningún archivo.
"""
from pathlib import Path
import argparse
import re
import sys

EXPECTED = "es.sergiotech.mixtick"
PROJECT = "mixtick"
ROOT = Path(__file__).resolve().parent.parent


def check(description, paths, pattern, value):
    candidates = [ROOT / p for p in paths]
    file = next((p for p in candidates if p.exists()), None)
    if not file:
        return False, f"NOT_RUN {description}: no existe ninguno de {[str(p.relative_to(ROOT)) for p in candidates]}"
    content = file.read_text('utf-8', errors='replace')
    match = re.search(pattern, content, re.MULTILINE)
    if not match:
        return False, f"FAIL {description}: valor no detectado en {file.relative_to(ROOT)}"
    got = match.group(1)
    if got != value:
        return False, f"FAIL {description}: encontrado {got!r}; esperado {value!r}"
    return True, f"PASS {description}: {got}"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--strict', action='store_true', help='devuelve error si falta cualquier archivo o comprobación')
    args = parser.parse_args()
    cases = [
        check('Flutter package', ['pubspec.yaml'], r'^name:\s*([A-Za-z0-9_]+)\s*$', PROJECT),
        check('Android namespace', ['android/app/build.gradle.kts','android/app/build.gradle'], r'\bnamespace\s*(?:=\s*)?[\"\']([^\"\']+)[\"\']', EXPECTED),
        check('Android applicationId', ['android/app/build.gradle.kts','android/app/build.gradle'], r'\bapplicationId\s*(?:=\s*)?[\"\']([^\"\']+)[\"\']', EXPECTED),
        check('Android MainActivity package', [
            'android/app/src/main/kotlin/es/sergiotech/mixtick/MainActivity.kt',
            'android/app/src/main/java/es/sergiotech/mixtick/MainActivity.java',
        ], r'^package\s+([A-Za-z0-9_.]+)\s*;?\s*$', EXPECTED),
    ]
    pbx = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
    if pbx.exists():
        data = pbx.read_text('utf-8', errors='replace')
        vals = re.findall(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([A-Za-z0-9_.-]+)\s*;', data)
        runner_vals = [x for x in vals if not x.endswith('.RunnerTests') and not x.endswith('.RunnerUITests')]
        if not runner_vals:
            cases.append((False,'FAIL iOS Bundle Identifier: sin valores detectados para Runner'))
        elif any(x != EXPECTED for x in runner_vals):
            cases.append((False,'FAIL iOS Bundle Identifier: '+repr(runner_vals)+' (esperado '+EXPECTED+')'))
        else:
            cases.append((True, f'PASS iOS Bundle Identifier: {len(runner_vals)} coincidencias con {EXPECTED}'))
    else:
        cases.append((False, 'NOT_RUN iOS Bundle Identifier: proyecto iOS aún no creado'))
    for _, info in cases:
        print(info)
    ok = all(status for status, _ in cases)
    print('RESULT:', 'PASS' if ok else 'INCOMPLETE/FAIL')
    return 0 if ok or not args.strict else 1


if __name__ == '__main__':
    sys.exit(main())
