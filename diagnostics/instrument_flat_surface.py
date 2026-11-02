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
            if stage == "thin":
                lines.extend([
                    f"{indent}if length(bt) >= {segment}:",
                    f'{indent}    message "S104-TKNOT " & decimal(traceHatchRow) & " "',
                    f'{indent}        & decimal(traceThisThin) & " " & decimal(i) & " {segment} "',
                    f'{indent}        & decimal(xpart(point {segment} of bt)) & " "',
                    f'{indent}        & decimal(ypart(point {segment} of bt)) & " "',
                    f'{indent}        & decimal(floor(ypart(point {segment} of bt)*256)) & " "',
                    f'{indent}        & decimal(round((ypart(point {segment} of bt)*256 - floor(ypart(point {segment} of bt)*256))*256));',
                    f"{indent}fi;",
                ])
                for index, point in enumerate((
                    f"point {segment} of bt",
                    f"postcontrol {segment} of bt",
                    f"precontrol {segment + 1} of bt",
                    f"point {segment + 1} of bt",
                )):
                    lines.extend([
                        f"{indent}if length(bt) > {segment}:",
                        f'{indent}    message "S104-TCTRL " & decimal(traceHatchRow) & " "',
                        f'{indent}        & decimal(traceThisThin) & " " & decimal(i) & " {segment} {index} "',
                        f'{indent}        & decimal(xpart({point})) & " " & decimal(ypart({point})) & " "',
                        f'{indent}        & decimal(floor(ypart({point})*256)) & " "',
                        f'{indent}        & decimal(round((ypart({point})*256 - floor(ypart({point})*256))*256));',
                        f"{indent}fi;",
                    ])
                    if stage == "thin":
                        lines.extend([
                            f"{indent}if length(bt) > {segment}:",
                            f'{indent}    message "S104-TXCTRL " & decimal(traceHatchRow) & " "',
                            f'{indent}        & decimal(traceThisThin) & " " & decimal(i) & " {segment} {index} "',
                            f'{indent}        & decimal(floor(xpart({point})*256)) & " "',
                            f'{indent}        & decimal(round((xpart({point})*256 - floor(xpart({point})*256))*256));',
                            f"{indent}fi;",
                        ])
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
            if stage == "outer":
                points = (
                    f"point {segment} of bt",
                    f"postcontrol {segment} of bt",
                    f"precontrol {segment + 1} of bt",
                    f"point {segment + 1} of bt",
                )
                parts = [
                    f'{indent}if length(bt) > {segment}:',
                    f'{indent}    message "S104-OCTRL " & decimal(traceHatchRow) & " "',
                    f'{indent}        & decimal(traceCutSerial) & " " & decimal(i) & " {segment} "',
                ]
                for point_index, point in enumerate(points):
                    suffix = ';' if point_index == len(points) - 1 else ' & " "'
                    parts.extend([
                        f'{indent}        & decimal(floor(ypart({point})*256)) & " "',
                        f'{indent}        & decimal(round((ypart({point})*256 - floor(ypart({point})*256))*256)){suffix}',
                    ])
                parts.append(f"{indent}fi;")
                lines.extend(parts)
                xparts = [
                    f'{indent}if length(bt) > {segment}:',
                    f'{indent}    message "S104-OXCTRL " & decimal(traceHatchRow) & " "',
                    f'{indent}        & decimal(traceCutSerial) & " " & decimal(i) & " {segment} "',
                ]
                for point_index, point in enumerate(points):
                    suffix = ';' if point_index == len(points) - 1 else ' & " "'
                    xparts.extend([
                        f'{indent}        & decimal(floor(xpart({point})*256)) & " "',
                        f'{indent}        & decimal(round((xpart({point})*256 - floor(xpart({point})*256))*256)){suffix}',
                    ])
                xparts.append(f"{indent}fi;")
                lines.extend(xparts)
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
        message "S104-OFIX " & decimal(traceHatchRow) & " "
            & decimal(traceCutSerial) & " " & decimal(i)
            & " " & decimal(floor(w0*256))
            & " " & decimal(round((w0*256-floor(w0*256))*256))
            & " " & decimal(floor(w1*256))
            & " " & decimal(round((w1*256-floor(w1*256))*256))
            & " " & decimal(floor(minStrokeWidth*256))
            & " " & decimal(round((minStrokeWidth*256-floor(minStrokeWidth*256))*256))
            & " " & decimal(floor(t*256))
            & " " & decimal(round((t*256-floor(t*256))*256));
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
    thin_trace = '''
        if traceFlatHatch:
            traceThinSerial := traceThinSerial + 1;
            traceThisThin := traceThinSerial;
            traceThinCutActive := true;
        fi;
''' + thin_brush + '''
        traceThinCutActive := false;
        if traceFlatHatch:
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
            message "S104-WFIX " & decimal(traceHatchRow) & " "
                & decimal(traceThisThin) & " " & decimal(i) & " "
                & decimal(floor(w2*256)) & " "
                & decimal(round((w2*256 - floor(w2*256))*256));
            if traceHatchRow = -6.37912:
                for tracePathControl := 0 step 1 until length(p) - 1:
                    message "S104-PCURVE " & decimal(traceHatchRow) & " "
                        & decimal(traceThisThin) & " " & decimal(tracePathControl) & " "
                        & decimal(xpart(point tracePathControl of p)/mm) & " "
                        & decimal(ypart(point tracePathControl of p)/mm) & " "
                        & decimal(xpart(postcontrol tracePathControl of p)/mm) & " "
                        & decimal(ypart(postcontrol tracePathControl of p)/mm) & " "
                        & decimal(xpart(precontrol (tracePathControl+1) of p)/mm) & " "
                        & decimal(ypart(precontrol (tracePathControl+1) of p)/mm) & " "
                        & decimal(xpart(point (tracePathControl+1) of p)/mm) & " "
                        & decimal(ypart(point (tracePathControl+1) of p)/mm);
                endfor;
            fi;
''' + control_trace("thin", "            ") + '''
        fi;'''
    if source.count(thin_brush) != 1:
        raise ValueError(f"expected one thin brush hook, found {source.count(thin_brush)}")
    source = source.replace(thin_brush, thin_trace)

    thin_function = "vardef thinBrushGenerate@#(expr p, q, i) =\nbegingroup\n"
    if source.count(thin_function) != 1:
        raise ValueError(f"expected one thin brush function, found {source.count(thin_function)}")
    source = source.replace(thin_function, thin_function +
        "    save traceThisThin, tracePathControl;\n"
        "    numeric traceThisThin, tracePathControl;\n"
        "    traceThisThin := 0;\n")

    cut_anchor = "        d4 := xpart (point cutTime1 of p);\n        d5 := xpart (point cutTime2 of p);"
    if source.count(cut_anchor) != 1:
        raise ValueError(f"expected one cutPathTime hit hook, found {source.count(cut_anchor)}")
    cut_header = "vardef cutPathTime (expr p, h) =\n    save cutTime, d;"
    if source.count(cut_header) != 1:
        raise ValueError("expected one cutPathTime declaration")
    source = source.replace(cut_header, cut_header + '''
    save traceRayA, traceRayB;
    path traceRayA, traceRayB;''')
    intersection_anchor = "    t1 := p intersectiontimes q;\n    t2 := p intersectiontimes reverse(q);"
    if source.count(intersection_anchor) != 1:
        raise ValueError("expected one firstIntersectionTimes search hook")
    source = source.replace(intersection_anchor, intersection_anchor + '''
    if traceFlatHatch:
        message "S104-RAW " & decimal(traceHatchRow) & " "
            & decimal(traceCutSerial) & " "
            & decimal(xpart(point 0 of p)) & " "
            & decimal(xpart(point length(p) of p)) & " "
            & decimal(xpart(t1)) & " " & decimal(ypart(t1)) & " "
            & decimal(xpart(t2)) & " " & decimal(ypart(t2));
    fi;
''')
    ray_trace = []
    for ray_id, ray in ((1, "traceRayA"), (2, "traceRayB")):
        points = (
            f"point 0 of {ray}", f"postcontrol 0 of {ray}",
            f"precontrol 1 of {ray}", f"point 1 of {ray}",
        )
        for control, point in enumerate(points):
            ray_trace.append(
                f'            message "S104-ORAY " & decimal(traceHatchRow) & " "'
                f' & decimal(traceCutSerial) & " {ray_id} {control} "'
                f' & decimal(floor(xpart({point})*256)) & " "'
                f' & decimal(round((xpart({point})*256 - floor(xpart({point})*256))*256));'
            )
    midpoint_anchor = "        d3 := 1/2(d1 + d2);"
    if source.count(midpoint_anchor) != 1:
        raise ValueError("expected one cutPathTime midpoint assignment")
    entry_anchor = "    d2 := xpart(ulcorner(p));"
    if source.count(entry_anchor) != 1:
        raise ValueError("expected one cutPathTime bounds assignment")
    source = source.replace(entry_anchor, entry_anchor + '''
    if traceFlatHatch:
        if traceThinCutActive:
            message "S104-TENTRY " & decimal(traceHatchRow) & " "
                & decimal(traceThinSerial) & " 1 "
                & decimal(d1) & " " & decimal(d2) & " " & decimal(length(p));
        else:
            message "S104-TENTRY " & decimal(traceHatchRow) & " 0 0 "
                & decimal(d1) & " " & decimal(d2) & " " & decimal(length(p));
        fi;
    fi;
''')
    thin_ray_trace = []
    for ray_id, ray in ((1, "traceRayA"), (2, "traceRayB")):
        points = (
            f"point 0 of {ray}", f"postcontrol 0 of {ray}",
            f"precontrol 1 of {ray}", f"point 1 of {ray}",
        )
        for control, point in enumerate(points):
            thin_ray_trace.extend([
                '            message "S104-TRAY " & decimal(traceHatchRow) & " "',
                f'                & decimal(traceThisThin) & " {ray_id} {control} "',
                f'                & decimal(floor(xpart({point})*256)) & " "',
                f'                & decimal(round((xpart({point})*256-floor(xpart({point})*256))*256)) & " "',
                f'                & decimal(floor(ypart({point})*256)) & " "',
                f'                & decimal(round((ypart({point})*256-floor(ypart({point})*256))*256));',
            ])
    source = source.replace(midpoint_anchor, midpoint_anchor + '''
        if traceThinCutActive:
            traceRayA := (d3, h) -- (d1, h);
            traceRayB := (d3, h) -- (d2, h);
''' + "\n".join(thin_ray_trace) + '''
        elseif traceFlatHatch:
            traceCutSerial := traceCutSerial + 1;
            traceRayA := (d3, h) -- (d1, h);
            traceRayB := (d3, h) -- (d2, h);
''' + "\n".join(ray_trace) + '''
        fi;
''')
    source = source.replace(cut_anchor, cut_anchor + '''
        if traceThinCutActive:
            message "S104-THIN-HIT-T " & decimal(traceHatchRow) & " "
                & decimal(traceThinSerial) & " " & decimal(h) & " "
                & decimal(d3) & " " & decimal(cutTime1) & " " & decimal(cutTime2);
            message "S104-THIN-HIT-X " & decimal(traceHatchRow) & " "
                & decimal(traceThinSerial) & " " & decimal(d4) & " " & decimal(d5);
            message "S104-THIN-HIT-FIX " & decimal(traceHatchRow) & " "
                & decimal(traceThinSerial) & " "
                & decimal(floor(h*256)) & " "
                & decimal(round((h*256-floor(h*256))*256)) & " "
                & decimal(floor(d3*256)) & " "
                & decimal(round((d3*256-floor(d3*256))*256));
            message "S104-THIN-TIMES-FIX " & decimal(traceHatchRow) & " "
                & decimal(traceThinSerial) & " "
                & decimal(floor(cutTime1*256)) & " "
                & decimal(round((cutTime1*256-floor(cutTime1*256))*256)) & " "
                & decimal(floor(cutTime2*256)) & " "
                & decimal(round((cutTime2*256-floor(cutTime2*256))*256));
            message "S104-THIN-POS-FIX " & decimal(traceHatchRow) & " "
                & decimal(traceThinSerial) & " "
                & decimal(floor(d4*256)) & " "
                & decimal(round((d4*256-floor(d4*256))*256)) & " "
                & decimal(floor(d5*256)) & " "
                & decimal(round((d5*256-floor(d5*256))*256));
        elseif traceFlatHatch:
            message "S104-HIT " & decimal(traceHatchRow) & " "
                & decimal(traceCutSerial) & " " & decimal(h) & " "
                & decimal(d1) & " " & decimal(d2) & " " & decimal(d3) & " "
                & decimal(cutTime1) & " " & decimal(cutTime2) & " "
                & decimal(d4) & " " & decimal(d5);
        fi;
''')
    first_intersection_anchor = "    t1 := p intersectiontimes q;\n    t2 := p intersectiontimes reverse(q);"
    if source.count(first_intersection_anchor) != 1:
        raise ValueError("expected one firstIntersectionTimes implementation")
    source = source.replace(first_intersection_anchor, first_intersection_anchor + '''
    if traceThinCutActive:
        message "S104-FIRST " & decimal(traceHatchRow) & " "
            & decimal(traceThinSerial) & " " & decimal(xpart(t1)) & " "
            & decimal(ypart(t1)) & " " & decimal(xpart(t2)) & " "
            & decimal(ypart(t2));
        message "S104-FIRST-FIX " & decimal(traceHatchRow) & " "
            & decimal(traceThinSerial) & " "
            & decimal(floor(xpart(t1)*256)) & " "
            & decimal(round((xpart(t1)*256-floor(xpart(t1)*256))*256)) & " "
            & decimal(floor(ypart(t1)*256)) & " "
            & decimal(round((ypart(t1)*256-floor(ypart(t1)*256))*256)) & " "
            & decimal(floor(xpart(t2)*256)) & " "
            & decimal(round((xpart(t2)*256-floor(xpart(t2)*256))*256)) & " "
            & decimal(floor(ypart(t2)*256)) & " "
            & decimal(round((ypart(t2)*256-floor(ypart(t2)*256))*256));
    fi;
''')
    source = source.replace(
        '        message "S104-OUTER " & decimal(traceHatchRow) & " "',
        '        message "S104-OUTER-ID " & decimal(traceHatchRow) & " "'
        '            & decimal(traceCutSerial) & " " & decimal(i);\n'
        '        message "S104-OUTER " & decimal(traceHatchRow) & " "',
    )
    source = source.replace(
        '            message "S104-WFIX " & decimal(traceHatchRow) & " "',
        '            message "S104-WFIX " & decimal(traceHatchRow) & " "'
        '                & decimal(traceCutSerial) & " "',
    )
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
boolean traceThinCutActive;
numeric traceHatchRow;
numeric traceThinSerial;
numeric traceCutSerial;
traceFlatHatch := false;
traceThinCutActive := false;
traceHatchRow := 0;
traceThinSerial := 0;
traceCutSerial := 0;
vardef traceUniformdeviate (expr x) =
    traceRngTotal := traceRngTotal + 1;
    uniformdeviate(x)
enddef;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
