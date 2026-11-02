#!/usr/bin/env python3
"""Trace source tubeOutline samples for the pinned M11 knot rendering.

Usage: instrument_m11_tube_outlines.py UPSTREAM_FIZIKO_MP OUTPUT_MP
"""

import re
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
                    message "M11TN " & decimal(i) & " " & decimal(j)
                        & " " & decimal(traceKnotRng) & " " & decimal(traceTubeCall);
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
    tube_start = "vardef tubeGenerate@#(expr p, q, d, i) ="
    if source.count(tube_start) != 1:
        raise ValueError(f"expected one tubeGenerate hook, found {source.count(tube_start)}")
    source = source.replace(tube_start,
        tube_start + "\n    if traceKnotActive: traceTubeCall := traceTubeCall + 1; fi;")
    lane_start = "                    brushGenerate (currentPath,\n                    offsetPathTemplate(currentPath, 0)("
    if source.count(lane_start) != 1:
        raise ValueError(f"expected one tube lane brush hook, found {source.count(lane_start)}")
    source = source.replace(lane_start,
        "                    if traceKnotActive: traceLaneStart := traceKnotRng; fi;\n"
        + lane_start)
    lane_end = "                    ), 0);\n                elseif (str @# = \"stipples\"):"
    if source.count(lane_end) != 1:
        raise ValueError(f"expected one tube lane brush end, found {source.count(lane_end)}")
    source = source.replace(lane_end,
        "                    ), 0);\n"
        '                    if traceKnotActive: message "M11LANE " & decimal(traceTubeCall)'
        ' & " " & decimal(k) & " "'
        ' & decimal(traceKnotRng-traceLaneStart); fi;\n'
        "                elseif (str @# = \"stipples\"):")
    knot_start = "    totalNumberOfSegments := 0;\n    for sNa := 1 step 1 until knotName.nStrands:"
    if source.count(knot_start) != 1:
        raise ValueError(f"expected one knot start hook, found {source.count(knot_start)}")
    source = source.replace(knot_start,
        "    totalNumberOfSegments := 0;\n"
        "    traceKnotRng := 0;\n"
        "    traceTubeCall := 0;\n"
        "    traceKnotActive := true;\n"
        '    message "M11TSTART " & decimal(traceCallBlocks) & " "'
        ' & decimal(traceCallRemainder);\n'
        "    for sNa := 1 step 1 until knotName.nStrands:")
    # MetaPost permits implicit multiplication, as in `1/2uniformdeviate(...)`;
    # a word-boundary matcher misses that call because the preceding `2` is a
    # word character. Match any non-letter prefix instead.
    source = re.sub(r"(?<![A-Za-z])uniformdeviate\s*\(", "traceKnotDeviate(", source)
    source += """
numeric traceMaskTime, traceKnotRng, traceLaneStart, traceTubeCall;
numeric traceCallBlocks, traceCallRemainder;
boolean traceKnotActive;
traceKnotRng := 0;
traceCallBlocks := 0;
traceCallRemainder := 0;
traceKnotActive := false;
vardef traceKnotDeviate (expr x) =
    traceCallRemainder := traceCallRemainder + 1;
    if traceCallRemainder >= 1000:
        traceCallRemainder := traceCallRemainder - 1000;
        traceCallBlocks := traceCallBlocks + 1;
    fi;
    if traceKnotActive:
        traceKnotRng := traceKnotRng + 1;
    fi;
    uniformdeviate(x)
enddef;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
