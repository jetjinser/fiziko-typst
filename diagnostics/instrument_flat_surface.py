#!/usr/bin/env python3
"""Add row geometry messages to a copy of the upstream flatSurface macro.

Usage: instrument_flat_surface.py UPSTREAM_FIZIKO_MP OUTPUT_MP
"""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source = Path(sys.argv[1]).read_text()
    anchor = "            hatchLength := arclength(aHatch);"
    if source.count(anchor) != 1:
        raise ValueError(f"expected one flatSurface row hook, found {source.count(anchor)}")
    source = source.replace(
        anchor,
        anchor
        + '\n                message "FSROW " & decimal(i) & " "'
        ' & decimal(hatchLength) & " " & decimal(totalWidth)'
        ' & " " & decimal(distFromEdge);',
    )
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
