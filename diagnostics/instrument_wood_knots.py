#!/usr/bin/env python3
"""Add a candidate-knot trace to a copy of the upstream MetaPost source."""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: instrument_wood_knots.py UPSTREAM_FIZIKO_MP OUTPUT_MP")
    source = Path(sys.argv[1]).read_text()
    anchor = (
        "wKnot[-1] := (uniformdeviate(wS*woodBlockDetail + "
        "woodKnotRadius*woodBlockDetail/woodBlockRes), "
        "uniformdeviate(lS*woodBlockDetail + "
        "woodKnotRadius*woodBlockDetail/woodBlockRes)) shifted "
        "(-1/2woodKnotRadius*woodBlockDetail/woodBlockRes, "
        "-1/2woodKnotRadius*woodBlockDetail/woodBlockRes);"
    )
    if source.count(anchor) != 1:
        raise ValueError(f"expected one wood-knot hook, found {source.count(anchor)}")
    hook = anchor + (
        '\n                message "WKCAND " & decimal(i) & " " & decimal(j) & " "'
        ' & decimal(woodBlockRes*xpart(wKnot[-1])/woodBlockDetail) & " "'
        ' & decimal(woodBlockRes*ypart(wKnot[-1])/woodBlockDetail) & " "'
        ' & decimal(traceRngCount) & " " & decimal(traceRngTotal);'
    )
    source = source.replace(anchor, hook)
    loop_anchor = "i := -1;\n            j := 0;"
    if source.count(loop_anchor) != 1:
        raise ValueError(f"expected one wood-knot loop reset, found {source.count(loop_anchor)}")
    source = source.replace(loop_anchor,
        loop_anchor + "\n            traceRngCount := 0;")
    angle_anchor = "surfaceAngle := findNarrowest(surfaceOutline);"
    if source.count(angle_anchor) != 1:
        raise ValueError(f"expected one wooden-surface angle hook, found {source.count(angle_anchor)}")
    angle_hook = angle_anchor + (
        '\n        message "WOODANGLE " & decimal(surfaceAngle) & " "'
        ' & decimal(traceRngTotal);'
    )
    source = source.replace(angle_anchor, angle_hook)
    source = source.replace("uniformdeviate(", "traceUniformdeviate(")
    source += """
numeric traceRngCount;
numeric traceRngTotal;
traceRngCount := 0;
traceRngTotal := 0;
vardef traceUniformdeviate (expr x) =
    traceRngCount := traceRngCount + 1;
    traceRngTotal := traceRngTotal + 1/100;
    uniformdeviate(x)
enddef;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
