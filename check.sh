#!/usr/bin/env bash
# Rebuild the specimen and run numeric + pixel-exact visual regression gates.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"

mkdir -p build/check

# Use the same font selection for the PDF, numerical checks and snapshots.
: "${FIZIKO_TEST_FONT_PATH:?Enter the project Nix devshell before running checks}"
export TYPST_FONT_PATHS="$FIZIKO_TEST_FONT_PATH"
export TYPST_IGNORE_SYSTEM_FONTS=true
unset TYPST_IGNORE_EMBEDDED_FONTS

printf '## Numeric geometry assertions\n'
typst eval 'query(<verify>).map(it => it.value)' --in verify.typ > build/check/geometry.json
printf 'Geometry assertions passed; metrics: build/check/geometry.json\n'
printf '## Regression harness tests\n'
python3 -m unittest discover -s visual -p 'test_*.py'
printf '## Typst compile\n'
typst compile main.typ build/check/main.pdf
printf '## Visual snapshot\n'
./visual-regression.sh
