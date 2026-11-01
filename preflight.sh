#!/usr/bin/env bash
# Preflight for main.pdf — print-readiness checks.
# Run inside `nix develop path:./nix`; all checker versions come from flake.lock.
set -euo pipefail
cd "$(dirname "$0")"

F=${1:-main.pdf}

for tool in qpdf pdfinfo pdffonts gs; do
  if ! command -v "$tool" >/dev/null; then
    printf 'Missing %s; run through nix develop path:./nix\n' "$tool" >&2
    exit 2
  fi
done

Q=$(mktemp --suffix=.pdf)
trap 'rm -f "$Q"' EXIT

echo "## pinned tool versions"
qpdf --version
pdfinfo -v 2>&1 | head -n 1
gs --version

echo "## structure (qpdf --check)"
qpdf --check "$F" 2>&1 | sed -n "1,5p"

echo "## page"
pdfinfo "$F" | grep -E "^(Pages|Page size|PDF version|Encrypted|Tagged|JavaScript)"

echo "## fonts (want emb=yes sub=yes for every row)"
pdffonts "$F"

echo "## render (Ghostscript, stop on error)"
gs -o /dev/null -sDEVICE=nullpage -dPDFSTOPONERROR -dQUIET "$F" && echo "no errors"

Q=$(mktemp --suffix=.pdf)
qpdf --qdf --object-streams=disable "$F" "$Q"

echo "## colour operators (want 0 for rg/RG/k/K in a K-only document)"
for op in " rg" " RG" " k" " K"; do
  printf "%-4s %s\n" "$op" "$(grep -ac -- "$op" "$Q" || true)"
done
echo "## scn colours"
grep -aoE "[0-9. ]+ scn" "$Q" | sort | uniq -c | sort -rn | head -8

echo "## transparency (want 0 each)"
for p in /SMask /ca /CA /BlendMode /Group; do
  printf "%-12s %s\n" "$p" "$(grep -ac -- "$p" "$Q" || true)"
done

echo "## images / annotations (want 0 / 0)"
printf "images=%s annots=%s\n" \
  "$(grep -ac "Subtype */Image" "$Q" || true)" "$(grep -ac "/Annot" "$Q" || true)"

echo "## stroked line widths in pt (report only; source strokes may be 0.2 pt)"
grep -aoE "[0-9.]+ w" "$Q" | tr -d " w" | sort -n | uniq -c

echo "## output intent (presence alone does not certify PDF/X)"
grep -ac "/OutputIntent" "$Q" || true

echo "## PDF/X status"
echo "Not certified: this repository has no selected print output profile or PDF/X validator."
