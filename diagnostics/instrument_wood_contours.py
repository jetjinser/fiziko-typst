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
    boundary_anchor = "    else:\n        outputPath := (i, j);"
    boundary_trace = (
        '    else:\n'
        '        if traceWoodCells:\n'
        '            message "CLSTEP " & decimal(i) & " " & decimal(j) & " "\n'
        '                & decimal(st) & " 0 0 0";\n'
        '        fi;\n'
        '        outputPath := (i, j);'
    )
    source = replace_once(source, boundary_anchor, boundary_trace, "cLine boundary cell")

    call_anchor = "iL := cLine (xy)((i, j), (0, 0), 0, cs) scaled s;"
    call_trace = """traceWoodLine := traceWoodLine + 1;
                            traceWoodCells := (traceWoodLine = 1);
                            iL := cLine (xy)((i, j), (0, 0), 0, cs) scaled s;
                            if traceWoodLine = 1:
                                message "CLLEVEL " & decimal(lvl);
                                message "CLLEVELFIX "
                                    & decimal(floor(lvl*256)) & " "
                                    & decimal(round((lvl*256-floor(lvl*256))*256));
                                message "CLSPAN " & decimal(sqB) & " "
                                    & decimal(sqBm) & " " & decimal(length(iL));
                                for traceWoodPoint := 0 step 1 until length(iL):
                                    message "CLPATH " & decimal(traceWoodPoint) & " "
                                        & decimal(xpart(point traceWoodPoint of iL)/mm) & " "
                                        & decimal(ypart(point traceWoodPoint of iL)/mm);
                                endfor;
                            fi;
                            traceWoodCells := false;"""
    source = replace_once(source, call_anchor, call_trace, "isoLines call")

    width_anchor = "offsetPathTemplate(iL, 0)(\n"
    width_trace = """offsetPathTemplate(iL, 0)(
                            begingroup
                            if traceWoodLine = 1:
                                if (offsetPathTime < length(iL) - 1):
                                    message "CLWIDTH " & decimal(offsetPathTime) & " "
                                        & decimal(sqB) & " " & decimal(sqBm) & " "
                                        & decimal(length(iL)) & " "
                                        & decimal(v[floor(sqB + offsetPathTime)]) & " "
                                        & decimal(v[ceiling(sqB + offsetPathTime)]);
                                else:
                                    message "CLWIDTH " & decimal(offsetPathTime) & " "
                                        & decimal(sqB) & " " & decimal(sqBm) & " "
                                        & decimal(length(iL)) & " 1 1";
                                fi;
                            fi;
                            """
    source = replace_once(source, width_anchor, width_trace, "isoLines width callback")
    width_end_anchor = "\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t, 0);"
    width_end_trace = """\t\t\t\t\t\t\tendgroup
\t\t\t\t\t\t\t)
\t\t\t\t\t\t\t, 0);"""
    source = replace_once(source, width_end_anchor, width_end_trace,
                           "isoLines width callback end")

    brush_anchor = "    t := cutPathTime(bt, minStrokeWidth);"
    brush_trace = brush_anchor + """
    if traceWoodLine = 1:
        message "WBNODE " & decimal(i) & " " & decimal(w0/mm) & " "
            & decimal(w1/mm) & " " & decimal(t) & " " & decimal(arclength(p)/mm);
        message "WBCUT " & decimal(i) & " "
            & decimal(xpart(point t of p)/mm) & " "
            & decimal(ypart(point t of p)/mm);
    fi;"""
    source = replace_once(source, brush_anchor, brush_trace, "brush recursion node")
    fill_anchor = "            fill brushPath1 -- reverse(brushPath2) -- cycle;"
    fill_trace = """            if traceWoodLine = 1:
                message "WBLEAF FILL " & decimal(i) & " " & decimal(w0/mm) & " "
                    & decimal(w1/mm) & " " & decimal(arclength(p)/mm);
            fi;
""" + fill_anchor
    source = replace_once(source, fill_anchor, fill_trace, "brush fill leaf")
    thin_anchor = "            thinBrushGenerate (p, q, 0)"
    thin_trace = """            if traceWoodLine = 1:
                message "WBLEAF THIN " & decimal(i) & " " & decimal(w0/mm) & " "
                    & decimal(w1/mm) & " " & decimal(arclength(p)/mm);
            fi;
""" + thin_anchor
    source = replace_once(source, thin_anchor, thin_trace, "brush thin leaf")

    thin_split_anchor = "        brushPath2 := subpath (t, length(p)) of p;"
    fixed_widths = ("w0", "w1", "w2", "minWidth", "dashStrokeWidthStep")
    fixed_trace = [
        '            message "WBTFIX " & decimal(traceThinCall) & " " & decimal(i) & " "'
    ]
    for index, width in enumerate(fixed_widths):
        suffix = ';' if index == len(fixed_widths) - 1 else ' & " "'
        fixed_trace.extend([
            f'                & decimal(floor({width}*256)) & " "',
            f'                & decimal(round(({width}*256-floor({width}*256))*256)){suffix}',
        ])
    thin_split_trace = thin_split_anchor + """
        if traceWoodLine = 1:
""" + "\n".join(fixed_trace) + """
            if (((w0 - w1) >= dashStrokeWidthStep) and (i < 15))
                and ((arclength(brushPath1) > minLength)
                or (arclength(brushPath2) > minLength))
                and (t > 1/100) and (t < length(p) - 1/100):
                message "WBTHIN " & decimal(traceThinCall) & " " & decimal(i) & " R " & decimal(w0/mm) & " "
                    & decimal(w1/mm) & " " & decimal(w2/mm) & " "
                    & decimal(t) & " " & decimal(arclength(p)/mm) & " "
                    & decimal(arclength(brushPath1)/mm) & " "
                    & decimal(arclength(brushPath2)/mm);
            else:
                message "WBTHIN " & decimal(traceThinCall) & " " & decimal(i) & " L " & decimal(w0/mm) & " "
                    & decimal(w1/mm) & " " & decimal(w2/mm) & " "
                    & decimal(t) & " " & decimal(arclength(p)/mm) & " "
                    & decimal(arclength(brushPath1)/mm) & " "
                    & decimal(arclength(brushPath2)/mm);
            fi;
            message "WBTHINPATH " & decimal(i) & " "
                & decimal(xpart(point 0 of p)/mm) & " "
                & decimal(ypart(point 0 of p)/mm) & " "
                & decimal(xpart(point length(p) of p)/mm) & " "
                & decimal(ypart(point length(p) of p)/mm);
            message "WBTHINCUT " & decimal(i) & " "
                & decimal(xpart(point t of p)/mm) & " "
                & decimal(ypart(point t of p)/mm);
        fi;"""
    source = replace_once(source, thin_split_anchor, thin_split_trace,
                           "thin brush split trace")
    thin_call_anchor = "    if (w0 > minWidth + 1/100):"
    q_points = (
        "point traceQSegment of bt",
        "postcontrol traceQSegment of bt",
        "precontrol (traceQSegment + 1) of bt",
        "point (traceQSegment + 1) of bt",
    )
    q_trace = [
        "        for traceQSegment := 0 step 1 until length(bt) - 1:",
        '            message "WBQCTRL " & decimal(traceThinCall) & " " & decimal(i) & " "',
        '                & decimal(traceQSegment) & " "',
    ]
    for point_index, point in enumerate(q_points):
        for coordinate in (f"xpart({point})", f"ypart({point})"):
            suffix = ';' if point_index == len(q_points) - 1 and coordinate.startswith("ypart") else ' & " "'
            q_trace.extend([
                f'                & decimal(floor({coordinate}*256)) & " "',
                f'                & decimal(round(({coordinate}*256-floor({coordinate}*256))*256)){suffix}',
            ])
    q_trace.append("        endfor;")
    thin_call_trace = """    if traceWoodLine = 1:
        traceThinCall := traceThinCall + 1;
        message "WBTCALL " & decimal(traceThinCall) & " " & decimal(i) & " "
            & decimal(w0/mm) & " " & decimal(w1/mm) & " " & decimal(arclength(p)/mm)
            & " " & decimal(xpart(point 0 of p)/mm) & " "
            & decimal(ypart(point 0 of p)/mm) & " "
            & decimal(xpart(point length(p) of p)/mm) & " "
            & decimal(ypart(point length(p) of p)/mm);
""" + "\n".join(q_trace) + """
    fi;
""" + thin_call_anchor
    source = replace_once(source, thin_call_anchor, thin_call_trace,
                           "thin brush call trace")
    dash_anchor = "                        draw p withpen thinpen dashed thinBrushPattern(w2, arclength(p));"
    dash_trace = """                        if traceWoodLine = 1:
                            message "WBTHINDASH " & decimal(traceThinCall) & " "
                                & decimal(i) & " "
                                & decimal(w2/mm) & " " & decimal(arclength(p)/mm)
                                & " " & decimal(xpart(point 0 of p)/mm) & " "
                                & decimal(ypart(point 0 of p)/mm) & " "
                                & decimal(xpart(point length(p) of p)/mm) & " "
                                & decimal(ypart(point length(p) of p)/mm);
                        fi;
""" + dash_anchor
    source = replace_once(source, dash_anchor, dash_trace, "thin brush dash leaf")

    range_anchor = "for i := -maxWithinMask/woodBlockYRdensity - 1 upto -minWithinMask/woodBlockYRdensity + 1:"
    range_trace = (
        'message "CLFIELD " & decimal(minWithinMask) & " " & decimal(maxWithinMask);\n'
        'message "CLFIELDFIX " '
        '& decimal(floor(minWithinMask*256)) & " " '
        '& decimal(round((minWithinMask*256-floor(minWithinMask*256))*256)) & " " '
        '& decimal(floor(maxWithinMask*256)) & " " '
        '& decimal(round((maxWithinMask*256-floor(maxWithinMask*256))*256));\n'
        + range_anchor
    )
    source = replace_once(source, range_anchor, range_trace, "wood field range")
    field_anchor = "wood[i][j] := wField (wKnot)(i, j, (wS, lS), nwKnot) + k;"
    field_trace = field_anchor + """
                if traceWoodBlock = 1:
                    if i <= 5:
                        if (j >= 12) and (j <= 23):
                            message "CLVALUE " & decimal(i) & " " & decimal(j) & " "
                                & decimal(wood[i][j]);
                            message "CLVFIX " & decimal(i) & " " & decimal(j) & " "
                                & decimal(floor(wood[i][j]*256)) & " "
                                & decimal(round((wood[i][j]*256-floor(wood[i][j]*256))*256));
                        fi;
                    fi;
                fi;"""
    source = replace_once(source, field_anchor, field_trace, "wood field sample")
    max_anchor = "if wood[i][j] > maxWithinMask:"
    max_trace = max_anchor + "\n                            message \"CLMAX \" & decimal(i) & \" \" & decimal(j) & \" \" & decimal(wood[i][j]);"
    source = replace_once(source, max_anchor, max_trace, "wood field maximum")
    level_anchor = "draw isoLines(wood)((wS, lS), woodBlockYRdensity*i + uniformdeviate(1/8woodBlockYRdensity), woodBlockRes);"
    level_trace = """if traceWoodBlock = 1:
                    traceWoodJitter := uniformdeviate(1/8woodBlockYRdensity);
                    message "CLDRAW " & decimal(i) & " " & decimal(traceWoodJitter);
                    message "CLDRAWFIX "
                        & decimal(floor(traceWoodJitter*256)) & " "
                        & decimal(round((traceWoodJitter*256-floor(traceWoodJitter*256))*256));
                    draw isoLines(wood)((wS, lS), woodBlockYRdensity*i + traceWoodJitter, woodBlockRes);
                else:
                    draw isoLines(wood)((wS, lS), woodBlockYRdensity*i + uniformdeviate(1/8woodBlockYRdensity), woodBlockRes);
                fi;"""
    source = replace_once(source, level_anchor, level_trace, "wood contour jitter draw")
    block_anchor = "vardef woodBlock (expr w, l) ="
    block_trace = block_anchor + "\n    traceWoodBlock := traceWoodBlock + 1;"
    source = replace_once(source, block_anchor, block_trace, "wood block")
    source += """

boolean traceWoodCells;
numeric traceWoodLine, traceWoodPoint, traceWoodBlock, traceThinCall, traceQSegment;
traceWoodCells := false;
traceWoodLine := 0;
traceWoodBlock := 0;
traceThinCall := 0;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
