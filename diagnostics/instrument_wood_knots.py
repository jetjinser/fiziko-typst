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
    ring_anchor = (
        "                    for tr := 2woodKnotRadius step -8minStrokeWidth until 2minStrokeWidth:\n"
        "                        draw brush(\n"
    )
    if source.count(ring_anchor) != 1:
        raise ValueError(f"expected one wood-knot ring loop, found {source.count(ring_anchor)}")
    ring_hook = (
        "                    for tr := 2woodKnotRadius step -8minStrokeWidth until 2minStrokeWidth:\n"
        '                        message "WKRINGSTART " & decimal(traceWoodCount) & " "'
        ' & decimal(i) & " " & decimal(tr) & " " & decimal(traceRngBatches)'
        ' & " " & decimal(traceRngCalls);\n'
        "                        draw brush(\n"
    )
    source = source.replace(ring_anchor, ring_hook)
    ring_end = "                        );\n                    endfor;"
    if source.count(ring_end) != 1:
        raise ValueError(f"expected one wood-knot ring end, found {source.count(ring_end)}")
    source = source.replace(ring_end, (
        "                        );\n"
        '                        message "WKRINGEND " & decimal(traceWoodCount) & " "'
        ' & decimal(i) & " " & decimal(tr) & " " & decimal(traceRngBatches)'
        ' & " " & decimal(traceRngCalls);\n'
        "                    endfor;"
    ))
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
        ' & decimal(traceRngTotal) & " "'
        ' & decimal(xpart(urcorner(surfaceOutline))-xpart(llcorner(surfaceOutline))) & " "'
        ' & decimal(ypart(urcorner(surfaceOutline))-ypart(llcorner(surfaceOutline)));'
    )
    source = source.replace(angle_anchor, angle_hook)
    block_anchor = (
        "thingWoodBlock := woodBlock(xpart(urcorner(shiftedThing)), "
        "ypart(urcorner(shiftedThing)));"
    )
    if source.count(block_anchor) != 1:
        raise ValueError(f"expected one woodenThing block hook, found {source.count(block_anchor)}")
    block_hook = block_anchor + (
        '\n    message "WDBLOCKEND " & decimal(traceWoodCount) & " "'
        ' & decimal(traceRngBatches) & " " & decimal(traceRngCalls);'
        '\n    traceWoodCount := traceWoodCount + 1;'
    )
    source = source.replace(block_anchor, block_hook)
    source = source.replace("uniformdeviate(", "traceUniformdeviate(")
    source += """
numeric traceRngCount;
numeric traceRngTotal;
numeric traceRngCalls;
numeric traceRngBatches;
numeric traceWoodCount;
traceRngCount := 0;
traceRngTotal := 0;
traceRngCalls := 0;
traceRngBatches := 0;
traceWoodCount := 0;
vardef traceUniformdeviate (expr x) =
    traceRngCount := traceRngCount + 1;
    traceRngTotal := traceRngTotal + 1/100;
    traceRngCalls := traceRngCalls + 1;
    if traceRngCalls >= 1000:
        traceRngCalls := 0;
        traceRngBatches := traceRngBatches + 1;
    fi;
    uniformdeviate(x)
enddef;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
