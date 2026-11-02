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
        + '\n                traceRngTotal := 0;'
        '\n                message "FSROW " & decimal(i) & " "'
        ' & decimal(hatchLength) & " " & decimal(totalWidth)'
        ' & " " & decimal(distFromEdge) & " " & decimal(traceRngTotal)'
        ' & " " & decimal(surfLight) & " "'
        ' & decimal(2minStrokeWidth*(1/15+surfLight));',
    )

    # Trace the recursive width-template decisions made by the hatch brush.
    # The flag brackets only the S104 hatch draw, so unrelated plates remain
    # silent even though brushGenerate is used throughout the source.
    outer_brush = """    bt := q;
    w0 := (ypart(urcorner(bt)));
    w1 := (ypart(lrcorner(bt)));
    t := cutPathTime(bt, minStrokeWidth);"""
    def control_trace(stage: str, indent: str) -> str:
        # S104 subdivision asks for 3 or 5 pieces; fixed-point accumulation
        # may add a short terminal piece, so eight covers all observed paths.
        lines = []
        for segment in range(8):
            lines.extend([
                f"{indent}if length(bt) > {segment}:",
                f'{indent}    message "S104-CTRL {stage} " & decimal(traceHatchRow) & " "',
                f'{indent}        & decimal(i) & " {segment} "',
                f'{indent}        & decimal(xpart(point {segment} of bt)) & " "',
                f'{indent}        & decimal(ypart(point {segment} of bt)) & " "',
                f'{indent}        & decimal(xpart(postcontrol {segment} of bt)) & " "',
                f'{indent}        & decimal(ypart(postcontrol {segment} of bt)) & " "',
                f'{indent}        & decimal(xpart(precontrol {segment + 1} of bt)) & " "',
                f'{indent}        & decimal(ypart(precontrol {segment + 1} of bt)) & " "',
                f'{indent}        & decimal(xpart(point {segment + 1} of bt)) & " "',
                f'{indent}        & decimal(ypart(point {segment + 1} of bt));',
                f"{indent}fi;",
            ])
        return "\n".join(lines)
    outer_trace = outer_brush + '''
    if traceFlatHatch:
        message "S104-SEG " & decimal(traceHatchRow) & " "
            & decimal(i) & " "
            & decimal(xpart(point 0 of p)/mm) & " "
            & decimal(ypart(point 0 of p)/mm) & " "
            & decimal(xpart(point length(p) of p)/mm) & " "
            & decimal(ypart(point length(p) of p)/mm);
        message "S104-OUTER " & decimal(traceHatchRow) & " "
            & decimal(i) & " " & decimal(w0) & " " & decimal(w1)
            & " " & decimal(t) & " " & decimal(arclength(p))
            & " " & decimal(xpart(point 0 of p)/mm)
            & " " & decimal(ypart(point 0 of p)/mm)
            & " " & decimal(xpart(point length(p) of p)/mm)
            & " " & decimal(ypart(point length(p) of p)/mm);
        if (t > 0) and (t < length(p)):
            message "S104-CUT " & decimal(traceHatchRow) & " " & decimal(i)
                & " " & decimal(xpart(point t of p)/mm)
                & " " & decimal(ypart(point t of p)/mm);
        fi;
''' + control_trace("outer", "        ") + '''
    fi;'''
    if source.count(outer_brush) != 1:
        raise ValueError(f"expected one outer brush hook, found {source.count(outer_brush)}")
    source = source.replace(outer_brush, outer_trace)

    thin_brush = """        t := cutPathTime(bt, w2);
        brushPath1 := subpath (0, t) of p;
        brushPath2 := subpath (t, length(p)) of p;"""
    thin_trace = thin_brush + '''
        if traceFlatHatch:
            traceThinSerial := traceThinSerial + 1;
            traceThisThin := traceThinSerial;
            message "S104-TNODE " & decimal(traceHatchRow) & " "
                & decimal(traceThisThin) & " " & decimal(i) & " "
                & decimal(xpart(point 0 of p)/mm) & " "
                & decimal(ypart(point 0 of p)/mm) & " "
                & decimal(xpart(point length(p) of p)/mm) & " "
                & decimal(ypart(point length(p) of p)/mm);
            message "S104-THIN " & decimal(traceHatchRow) & " "
                & decimal(traceThisThin) & " " & decimal(i) & " " & decimal(w0) & " " & decimal(w1)
                & " " & decimal(w2) & " " & decimal(minWidth)
                & " " & decimal(dashStrokeWidthStep) & " " & decimal(t)
                & " " & decimal(arclength(p))
                & " " & decimal(arclength(brushPath1))
                & " " & decimal(arclength(brushPath2));
''' + control_trace("thin", "            ") + '''
        fi;'''
    if source.count(thin_brush) != 1:
        raise ValueError(f"expected one thin brush hook, found {source.count(thin_brush)}")
    source = source.replace(thin_brush, thin_trace)

    thin_function = "vardef thinBrushGenerate@#(expr p, q, i) =\nbegingroup\n"
    if source.count(thin_function) != 1:
        raise ValueError(f"expected one thin brush function, found {source.count(thin_function)}")
    source = source.replace(thin_function, thin_function +
        "    save traceThisThin;\n"
        "    numeric traceThisThin;\n"
        "    traceThisThin := 0;\n")
    thin_dash = "                        draw p withpen thinpen dashed thinBrushPattern(w2, arclength(p));"
    if source.count(thin_dash) != 1:
        raise ValueError(f"expected one thin dash draw hook, found {source.count(thin_dash)}")
    source = source.replace(thin_dash,
        "                        if traceFlatHatch: message \"S104-TDASH \" & decimal(traceHatchRow) & \" \" & decimal(traceThisThin); fi;\n"
        + thin_dash)

    hatch_draw = "                    draw brush(aHatch)("
    if source.count(hatch_draw) != 1:
        raise ValueError(f"expected one S104 hatch draw hook, found {source.count(hatch_draw)}")
    source = source.replace(hatch_draw,
        "                    traceFlatHatch := true;\n"
        "                    traceHatchRow := i;\n" + hatch_draw)
    draw_end = "                        );\n                elseif (str @# = \"stipples\"):"
    if source.count(draw_end) != 1:
        raise ValueError(f"expected one S104 hatch draw end, found {source.count(draw_end)}")
    source = source.replace(draw_end,
        "                        );\n"
        "                    traceFlatHatch := false;\n"
        "                elseif (str @# = \"stipples\"):")
    subdivide_anchor = "aHatch := pathSubdivide(aHatch,3+round(uniformdeviate(2)));"
    if source.count(subdivide_anchor) != 1:
        raise ValueError(f"expected one pathSubdivide hook, found {source.count(subdivide_anchor)}")
    source = source.replace(
        subdivide_anchor,
        "traceSubdivisions := 3+round(uniformdeviate(2));\n"
        "                aHatch := pathSubdivide(aHatch,traceSubdivisions);\n"
        "                message \"FSSUB \" & decimal(arclength(aHatch)) & \" \""
        " & decimal(length(aHatch)) & \" \" & decimal(traceSubdivisions);",
    )
    end_anchor = "            fi;\n        endfor;\n    );\n    clip hatchImage to surfPath;"
    if source.count(end_anchor) != 1:
        raise ValueError(f"expected one flatSurface row end hook, found {source.count(end_anchor)}")
    source = source.replace(end_anchor, """            fi;
            message "FSEND " & decimal(i) & " " & decimal(traceRngTotal);
        endfor;
    );
    clip hatchImage to surfPath;""")
    source = source.replace("uniformdeviate(", "traceUniformdeviate(")
    source += """

numeric traceRngTotal;
traceRngTotal := 0;
numeric traceSubdivisions;
traceSubdivisions := 0;
boolean traceFlatHatch;
numeric traceHatchRow;
numeric traceThinSerial;
traceFlatHatch := false;
traceHatchRow := 0;
traceThinSerial := 0;
vardef traceUniformdeviate (expr x) =
    traceRngTotal := traceRngTotal + 1;
    uniformdeviate(x)
enddef;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
