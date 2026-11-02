#!/usr/bin/env python3
"""Add source-path sample messages to a copy of the pinned M11 driver."""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) not in (3, 4):
        raise SystemExit(
            "usage: instrument_m11_knot_paths.py MAIN_MP OUTPUT_MP [STEP_DENOMINATOR]"
        )
    source_path, output_path = map(Path, sys.argv[1:3])
    step_denominator = int(sys.argv[3]) if len(sys.argv) == 4 else 8
    if step_denominator <= 0:
        raise SystemExit("STEP_DENOMINATOR must be positive")
    source = source_path.read_text()
    anchor = '  addStrandToKnot(weave)(wa,.8mm,"l","-1,1,-1,1");'
    trace = f"""  for ti := 0 step 1/{step_denominator} until length(wa):
    message "M11PATH A " & decimal(ti) & " " & decimal(xpart(point ti of wa)/mm) & " " & decimal(44-ypart(point ti of wa)/mm);
    message "M11PATH B " & decimal(ti) & " " & decimal(xpart(point ti of wb)/mm) & " " & decimal(44-ypart(point ti of wb)/mm);
  endfor;
"""
    if source.count(anchor) != 1:
        raise ValueError(f"expected one M11 strand hook, found {source.count(anchor)}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(source.replace(anchor, trace + anchor))


if __name__ == "__main__":
    main()
