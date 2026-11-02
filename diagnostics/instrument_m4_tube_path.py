#!/usr/bin/env python3
"""Trace the pinned comparison driver's M4 centerline from MetaPost."""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) not in (3, 4):
        raise SystemExit(
            "usage: instrument_m4_tube_path.py MAIN_MP OUTPUT_MP [STEP_DENOMINATOR]"
        )
    source_path, output_path = map(Path, sys.argv[1:3])
    step_denominator = int(sys.argv[3]) if len(sys.argv) == 4 else 8
    if step_denominator <= 0:
        raise SystemExit("STEP_DENOMINATOR must be positive")
    source = source_path.read_text()
    anchor = "  draw tube.l(p)(6mm);"
    trace = f"""  for ti := 0 step 1/{step_denominator} until length(p):
    message "M4PATH " & decimal(ti) & " " & decimal(xpart(point ti of p)/mm) & " " & decimal(56-ypart(point ti of p)/mm);
  endfor;
"""
    if source.count(anchor) != 1:
        raise ValueError(f"expected one M4 tube draw hook, found {source.count(anchor)}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(source.replace(anchor, trace + anchor))


if __name__ == "__main__":
    main()
