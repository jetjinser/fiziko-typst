#!/usr/bin/env python3
"""Trace source knot intersection times in a copy of the pinned Fiziko macro."""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: instrument_m11_knot_crossings.py UPSTREAM_FIZIKO_MP OUTPUT_MP"
        )
    source = Path(sys.argv[1]).read_text()
    anchor = "                    appendList[sNa](intersectionsList, round(timeToAdd*10)/10, 1, true);"
    if source.count(anchor) != 1:
        raise ValueError(f"expected one knot crossing hook, found {source.count(anchor)}")
    trace = '''                    message "M11X " & decimal(sNa) & " " & decimal(sNb)
                        & " " & decimal(i) & " " & decimal(timeToAdd)
                        & " " & decimal(round(timeToAdd*10)/10) & " "
                        & decimal(xpart(point timeToAdd of inspectedPath)/mm)
                        & " " & decimal(44-ypart(point timeToAdd of inspectedPath)/mm);
'''
    Path(sys.argv[2]).write_text(source.replace(anchor, trace + anchor))


if __name__ == "__main__":
    main()
