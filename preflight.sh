#!/usr/bin/env bash
# Preflight for main.pdf — print-readiness checks.
# Needs nix (pulls poppler-utils, qpdf and ghostscript from the binary cache).
set -euo pipefail
cd "$(dirname "$0")"

F=${1:-main.pdf}

nix shell nixpkgs#poppler-utils nixpkgs#qpdf nixpkgs#ghostscript -c bash -eu -c '
F="$1"
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
for p in /SMask /BlendMode /Group; do
  printf "%-12s %s\n" "$p" "$(grep -ac -- "$p" "$Q" || true)"
done

echo "## images / annotations (want 0 / 0)"
printf "images=%s annots=%s\n" \
  "$(grep -ac "Subtype */Image" "$Q" || true)" "$(grep -ac "/Annot" "$Q" || true)"

echo "## stroked line widths in pt (want min >= 0.3)"
grep -aoE "[0-9.]+ w" "$Q" | tr -d " w" | sort -n | uniq -c

echo "## output intent (absent => not PDF/X)"
grep -ac "/OutputIntent" "$Q" || true

rm -f "$Q"
' _ "$F"
