#!/usr/bin/env python3
"""Add source-path sample messages to a copy of the pinned M11 driver."""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: instrument_m11_knot_paths.py MAIN_MP OUTPUT_MP"
        )
    source_path, output_path = map(Path, sys.argv[1:])
    source = source_path.read_text()
    anchor = '  addStrandToKnot(weave)(wa,.8mm,"l","-1,1,-1,1");'
    trace = """  for ti := 0 step 1/4 until length(wa):
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
