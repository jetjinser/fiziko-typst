#!/usr/bin/env python3
"""Trace woodBlock's rejection counter and source knot-index limit."""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: instrument_wood_knot_cap.py UPSTREAM_FIZIKO_MP OUTPUT_MP"
        )
    source = Path(sys.argv[1]).read_text()
    anchor = (
        "exitif (j >= 10) or "
        "(i >= 1/2((w/cm)*(l*cm))/(woodKnotDensity/cm));"
    )
    if source.count(anchor) != 1:
        raise ValueError(f"expected one woodBlock exit hook, found {source.count(anchor)}")
    trace = (
        'message "WDCAP " & decimal(w/mm) & " " & decimal(l/mm) & " "'
        ' & decimal(i) & " " & decimal(j) & " "'
        ' & decimal(1/2((w/cm)*(l*cm))/(woodKnotDensity/cm));\n            '
    )
    Path(sys.argv[2]).write_text(source.replace(anchor, trace + anchor))


if __name__ == "__main__":
    main()
