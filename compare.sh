#!/usr/bin/env bash
# Run from `nix develop path:./nix`; all generated files stay under build/.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"
exec python3 comparisons/run.py "$@"
