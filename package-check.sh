#!/usr/bin/env bash
# Compile a consumer document against the package in a clean local package path.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"
: "${FIZIKO_TEST_FONT_PATH:?Enter the project Nix devshell before package checks}"

VERSION=$(python3 -c 'import tomllib; print(tomllib.load(open("typst.toml", "rb"))["package"]["version"])')
PACKAGE="$ROOT/build/package-check/packages/local/fiziko/$VERSION"
mkdir -p "$PACKAGE" "$ROOT/build/package-check"
cp typst.toml fiziko.typ contour.typ solve.typ README.md "$PACKAGE/"

typst compile \
  --ignore-system-fonts \
  --package-path "$ROOT/build/package-check/packages" \
  --root "$ROOT" \
  checks/package-smoke.typ \
  build/package-check/package-smoke.pdf
