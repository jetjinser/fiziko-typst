#!/usr/bin/env python3
"""Trace the pinned comparison driver's M7 transverse-tube centerline."""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) not in (3, 4):
        raise SystemExit(
            "usage: instrument_m7_tube_path.py MAIN_MP OUTPUT_MP [STEP_DENOMINATOR]"
        )
    source_path, output_path = map(Path, sys.argv[1:3])
    step_denominator = int(sys.argv[3]) if len(sys.argv) == 4 else 8
    if step_denominator <= 0:
        raise SystemExit("STEP_DENOMINATOR must be positive")
    source = Path(source_path).read_text()
    anchor = "  draw tube.t(P(6,32)..P(40,14)..P(74,32)..P(104,16))(5mm);"
    trace = f"""  path traceMSevenPath;
  traceMSevenPath := P(6,32)..P(40,14)..P(74,32)..P(104,16);
  for ti := 0 step 1/{step_denominator} until length(traceMSevenPath):
    message "M7PATH " & decimal(ti) & " " & decimal(xpart(point ti of traceMSevenPath)/mm) & " " & decimal(42-ypart(point ti of traceMSevenPath)/mm);
  endfor;
  draw tube.t(traceMSevenPath)(5mm);
"""
    if source.count(anchor) != 1:
        raise ValueError(f"expected one M7 tube draw hook, found {source.count(anchor)}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(source.replace(anchor, trace.rstrip()))


if __name__ == "__main__":
    main()
