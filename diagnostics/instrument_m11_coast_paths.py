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
    arc_anchor = "        % In the following loop previously calculated segments of a landmass and"
    if source.count(arc_anchor) != 1:
        raise ValueError(f"expected one M11 horizon-sewing hook, found {source.count(arc_anchor)}")
    arc_trace = '''        for traceArcIndex := 0 upto pathNumber:
            if known horizonTimes[traceArcIndex]:
                message "M11ARC " & decimal(traceLandIndex) & " "
                    & decimal(traceArcIndex) & " "
                    & decimal(xpart(horizonTimes[traceArcIndex])) & " "
                    & decimal(ypart(horizonTimes[traceArcIndex]));
            fi;
        endfor;

'''
    source = source.replace(arc_anchor, arc_trace + arc_anchor)
    anchor = "            lm := drawLandMass(landmass[i], lon + 90, lat) scaled s;"
    if source.count(anchor) != 1:
        raise ValueError(f"expected one M11 landmass hook, found {source.count(anchor)}")
    trace = "            traceLandIndex := i;\n" + anchor + """
            for coastTime := 0 step 1/16 until length(lm):
                message "M11COAST " & decimal(i) & " "
                    & decimal(coastTime) & " "
                    & decimal(xpart(point coastTime of lm)/mm) & " "
                    & decimal(ypart(point coastTime of lm)/mm);
            endfor;
"""
    source = source.replace(anchor, trace)
    source += "\nnumeric traceLandIndex, traceArcIndex;\ntraceLandIndex := 0;\n"
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
