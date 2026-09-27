#!/usr/bin/env bash
# Rebuild the specimen and run numeric + pixel-exact visual regression gates.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

printf '## Typst compile\n'
typst compile main.typ main.pdf
printf '## Numeric geometry assertions\n'
typst eval 'query(<verify>).map(it => it.value)' --in verify.typ | tee "$tmp"
printf '## Visual snapshot\n'
./visual-regression.sh
