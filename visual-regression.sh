#!/usr/bin/env bash
# Exact decoded-pixel checks; run from the project's Nix devshell.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"

exec python3 visual/check.py "$@"
