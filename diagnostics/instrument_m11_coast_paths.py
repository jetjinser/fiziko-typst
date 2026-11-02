#!/usr/bin/env python3
"""Trace the pinned source's closed, projected M11 landmass contours."""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: instrument_m11_coast_paths.py UPSTREAM_FIZIKO_MP OUTPUT_MP"
        )
    source = Path(sys.argv[1]).read_text()
    anchor = "            lm := drawLandMass(landmass[i], lon + 90, lat) scaled s;"
    if source.count(anchor) != 1:
        raise ValueError(f"expected one M11 landmass hook, found {source.count(anchor)}")
    trace = anchor + """
            for coastTime := 0 step 1/16 until length(lm):
                message "M11COAST " & decimal(i) & " "
                    & decimal(coastTime) & " "
                    & decimal(xpart(point coastTime of lm)/mm) & " "
                    & decimal(ypart(point coastTime of lm)/mm);
            endfor;
"""
    Path(sys.argv[2]).write_text(source.replace(anchor, trace))


if __name__ == "__main__":
    main()
