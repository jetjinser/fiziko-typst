#!/usr/bin/env python3
"""Trace source tubeOutline samples for the pinned M11 knot rendering.

Usage: instrument_m11_tube_outlines.py UPSTREAM_FIZIKO_MP OUTPUT_MP
"""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source = Path(sys.argv[1]).read_text()
    anchor = (
        '                    draw tube.scantokens(segmentStyle[j])'
        '(pathSegments[j])(segmentWidth[j]) if segmentStyle[j] = "e": '
        'withpen thickpen fi;'
    )
    if source.count(anchor) != 1:
        raise ValueError(f"expected one knot tube draw hook, found {source.count(anchor)}")
    trace = anchor + '''
                    message "M11TS " & decimal(i) & " " & decimal(j)
                        & " " & decimal(length(pathSegments[j])) & " "
                        & decimal(xpart(point 0 of pathSegments[j])/mm) & " "
                        & decimal(ypart(point 0 of pathSegments[j])/mm) & " "
                        & decimal(xpart(point length(pathSegments[j]) of pathSegments[j])/mm) & " "
                        & decimal(ypart(point length(pathSegments[j]) of pathSegments[j])/mm);
                    for traceMaskTime := 0 step 1/8 until length(tubeOutline):
                        message "M11TO " & decimal(i) & " " & decimal(j)
                            & " " & decimal(traceMaskTime) & " "
                            & decimal(xpart(point traceMaskTime of tubeOutline)/mm)
                            & " " & decimal(ypart(point traceMaskTime of tubeOutline)/mm);
                    endfor;'''
    source = source.replace(anchor, trace)
    source += "\nnumeric traceMaskTime;\n"
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
