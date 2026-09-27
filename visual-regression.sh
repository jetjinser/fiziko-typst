#!/usr/bin/env bash
# Exact page snapshot check; run from the project's devshell with Typst 0.15.1.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"

version=$(typst --version)
case "$version" in
  "typst 0.15.1 "*) ;;
  *)
    printf 'visual baseline requires Typst 0.15.1; found: %s\n' "$version" >&2
    exit 2
    ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
typst compile main.typ "$tmp/page-{p}.png" --ppi 130

reference=visual/figure-11-page-5.png
actual="$tmp/page-5.png"
if ! cmp -s "$reference" "$actual"; then
  printf 'visual regression: Figure 11 differs from %s\n' "$reference" >&2
  printf 'reference: '
  sha256sum "$reference"
  printf 'actual:    '
  sha256sum "$actual"
  exit 1
fi
printf 'Figure 11 matches the Typst 0.15.1 / 130 ppi reference.\n'
