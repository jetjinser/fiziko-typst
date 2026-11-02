#!/usr/bin/env python3
"""Trace cLine's first wood contour cell visits in a copy of fiziko.mp."""

import sys
from pathlib import Path


def replace_once(source: str, anchor: str, replacement: str, name: str) -> str:
    count = source.count(anchor)
    if count != 1:
        raise ValueError(f"expected one {name} hook, found {count}")
    return source.replace(anchor, replacement)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: instrument_wood_contours.py UPSTREAM_FIZIKO_MP OUTPUT_MP")
    source = Path(sys.argv[1]).read_text()
    c_line_anchor = "    sqS := max(c1, c2, c3, c4) - min(c1, c2, c3, c4);"
    c_line_trace = c_line_anchor + """
        if traceWoodCells:
            message "CLSTEP " & decimal(i) & " " & decimal(j) & " "
                & decimal(st) & " " & decimal(sqS) & " "
                & decimal(xpart(dr)) & " " & decimal(ypart(dr));
        fi;"""
    source = replace_once(source, c_line_anchor, c_line_trace, "cLine cell")

    call_anchor = "iL := cLine (xy)((i, j), (0, 0), 0, cs) scaled s;"
    call_trace = """traceWoodLine := traceWoodLine + 1;
                            traceWoodCells := (traceWoodLine = 1);
                            iL := cLine (xy)((i, j), (0, 0), 0, cs) scaled s;
                            traceWoodCells := false;"""
    source = replace_once(source, call_anchor, call_trace, "isoLines call")
    source += """

boolean traceWoodCells;
numeric traceWoodLine;
traceWoodCells := false;
traceWoodLine := 0;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
