#!/usr/bin/env python3
"""Add row geometry messages to a copy of the upstream flatSurface macro.

Usage: instrument_flat_surface.py UPSTREAM_FIZIKO_MP OUTPUT_MP [PATH_CUBIC_ROWS]
"""

import sys
from pathlib import Path


def fixed_chunks(expression: str) -> str:
    whole = f"floor(({expression}))"
    high = f"floor((({expression}) - {whole}) * 256)"
    low = f"round(((({expression}) - {whole}) * 256 - {high}) * 256)"
    return f'decimal({whole}) & " " & decimal({high}) & " " & decimal({low})'


def main() -> None:
    if len(sys.argv) not in (3, 4):
        raise SystemExit(__doc__)
    path_cubic_rows = (-6.37912,)
    if len(sys.argv) == 4:
        try:
            path_cubic_rows = tuple(float(value) for value in sys.argv[3].split(","))
        except ValueError as error:
            raise SystemExit("PATH_CUBIC_ROWS must be comma-separated row values") from error
        if not path_cubic_rows:
            raise SystemExit("PATH_CUBIC_ROWS must contain at least one row")
    source = Path(sys.argv[1]).read_text()
    row_distance = f"abs(i - {path_cubic_rows[0]:.5f})"
    for row in path_cubic_rows[1:]:
        row_distance = f"min({row_distance}, abs(i - {row:.5f}))"
    callback_quarter = (
        "(2minStrokeWidth*(1/15+surfLight))*"
        "(1-6/7sqrt(sin(1/4*pi)*(hatchLength/totalWidth)*sin(distFromEdge*pi)))"
    )
    width_math_a = (
        "sin(1/4*pi)",
        "hatchLength/totalWidth",
        "sin(distFromEdge*pi)",
        "sin(1/4*pi)*(hatchLength/totalWidth)*sin(distFromEdge*pi)",
        "sqrt(sin(1/4*pi)*(hatchLength/totalWidth)*sin(distFromEdge*pi))",
    )
    width_math_b = (
        "(6/7)*sqrt(sin(1/4*pi)*(hatchLength/totalWidth)*sin(distFromEdge*pi))",
        "1-(6/7)*sqrt(sin(1/4*pi)*(hatchLength/totalWidth)*sin(distFromEdge*pi))",
        "1-6/7sqrt(sin(1/4*pi)*(hatchLength/totalWidth)*sin(distFromEdge*pi))",
        "1/15+surfLight",
    )
    width_math_c = (
        "2minStrokeWidth*(1/15+surfLight)",
        "(2minStrokeWidth*(1/15+surfLight))*(1-(6/7)*sqrt(sin(1/4*pi)*(hatchLength/totalWidth)*sin(distFromEdge*pi)))",
        callback_quarter,
    )
    width_input_message = (
        '                    message "S104-WIDTH-IN " & decimal(i) & " " & '
        + fixed_chunks("hatchLength") + ' & " " & '
        + fixed_chunks("totalWidth") + ' & " " & '
        + fixed_chunks("distFromEdge") + ' & " " & '
        + fixed_chunks("surfLight") + ' & " " & '
        + fixed_chunks(callback_quarter) + ";"
    )
    def width_math_message(tag: str, values: tuple[str, ...]) -> str:
        return (
            f'                    message "{tag} " & decimal(i) & " " & '
            + ' & " " & '.join(fixed_chunks(expression) for expression in values)
            + ";"
        )
    width_math_trace = "\n".join((
        width_math_message("S104-WIDTH-MATH-A", width_math_a),
        width_math_message("S104-WIDTH-MATH-B", width_math_b),
        width_math_message("S104-WIDTH-MATH-C", width_math_c),
    ))
    width_probe = (
        f"\n                if {row_distance} < 0.00001:\n"
        + width_input_message + "\n" + width_math_trace
        + "\n                fi;"
    )
    anchor = "            hatchLength := arclength(aHatch);"
    if source.count(anchor) != 1:
        raise ValueError(f"expected one flatSurface row hook, found {source.count(anchor)}")
    source = source.replace(
        anchor,
        anchor
        + '\n                message "S104-RNG-ABS-ROW " & decimal(i) & " " & decimal(traceRngAbsolute);'
        + '\n                traceRngTotal := 0;'
        '\n                message "FSROW " & decimal(i) & " "'
        ' & decimal(hatchLength) & " " & decimal(totalWidth)'
        ' & " " & decimal(distFromEdge) & " " & decimal(traceRngTotal)'
        ' & " " & decimal(surfLight) & " "'
        ' & decimal(2minStrokeWidth*(1/15+surfLight));'
        + width_probe,
    )

    template_knot = "    returnPath := (arclength(subpath (0, i) of p), offsetFunction);"
    if source.count(template_knot) != 1:
        raise ValueError("expected one offsetPathTemplate knot hook")
    source = source.replace(template_knot, template_knot + '''
    if traceFlatHatch:
        message "S104-TEMPLATE-KNOT " & decimal(traceHatchRow) & " "
            & decimal(i) & " "
            & ''' + fixed_chunks("xpart(point 0 of returnPath)") + ''' & " "
            & ''' + fixed_chunks("ypart(point 0 of returnPath)") + ''' & " "
            & ''' + fixed_chunks("offsetPathLength") + ''';
    fi;''')

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
    clip_anchor = (
        "            aHatch := (xpart(llcorner(p)),i) -- (xpart(lrcorner(p)), i);\n"
        "            aHatch := (point xpart(aHatch firstIntersectionTimes p) of aHatch) --\n"
        "                (point xpart(reverse(aHatch) firstIntersectionTimes p) of reverse(aHatch));"
    )
    if source.count(clip_anchor) != 1:
        raise ValueError(f"expected one flatSurface clip block, found {source.count(clip_anchor)}")
    clip_row_distance = f"abs(i - {path_cubic_rows[0]:.5f})"
    for row in path_cubic_rows[1:]:
        clip_row_distance = f"min({clip_row_distance}, abs(i - {row:.5f}))"
    clip_row_condition = f"{clip_row_distance} < 0.00001"
    clip_trace = f'''            aHatch := (xpart(llcorner(p)),i) -- (xpart(lrcorner(p)), i);
            if traceFlatClip and ({clip_row_condition}):
                for traceClipIndex := 0 step 1 until length(surfPath):
                    traceClipPoint("S104-CLIP-SURF", i, traceClipIndex, point traceClipIndex of surfPath);
                endfor;
                for traceClipIndex := 0 step 1 until length(p):
                    traceClipPoint("S104-CLIP-POLY", i, traceClipIndex, point traceClipIndex of p);
                endfor;
                for traceClipIndex := 0 step 1 until length(p)-1:
                    traceClipPoint("S104-CLIP-POLY-POST", i, traceClipIndex, postcontrol traceClipIndex of p);
                    traceClipPoint("S104-CLIP-POLY-PRE", i, traceClipIndex, precontrol (traceClipIndex+1) of p);
                endfor;
                traceClipPoint("S104-CLIP-RAW", i, 0, point 0 of aHatch);
                traceClipPoint("S104-CLIP-RAW", i, 1, point 1 of aHatch);
                traceClipPoint("S104-CLIP-RAY-POST", i, 0, postcontrol 0 of aHatch);
                traceClipPoint("S104-CLIP-RAY-PRE", i, 0, precontrol 1 of aHatch);
            fi;
            traceClipInput := aHatch;
            traceClipForward := aHatch firstIntersectionTimes p;
            traceClipReverse := reverse(aHatch) firstIntersectionTimes p;
            aHatch := (point xpart(traceClipForward) of aHatch) --
                (point xpart(traceClipReverse) of reverse(aHatch));
            if traceFlatClip and (arclength(aHatch) > 0):
                traceClipPair("S104-CLIP-ROW", i, i, 0);
                traceClipPoint("S104-CLIP-RAW", i, 0, point 0 of traceClipInput);
                traceClipPoint("S104-CLIP-RAW", i, 1, point 1 of traceClipInput);
                traceClipPair("S104-CLIP-T1", i, xpart(traceClipForward), ypart(traceClipForward));
                traceClipPair("S104-CLIP-T2", i, xpart(traceClipReverse), ypart(traceClipReverse));
                traceClipPoint("S104-CLIP-HIT", i, 0, point xpart(traceClipForward) of traceClipInput);
                traceClipPoint("S104-CLIP-HIT", i, 1, point xpart(traceClipReverse) of reverse(traceClipInput));
                traceClipPoint("S104-CLIP-OUT", i, 0, point 0 of aHatch);
                traceClipPoint("S104-CLIP-OUT", i, 1, point 1 of aHatch);
            fi;'''
    source = source.replace(clip_anchor, clip_trace)
    flat_surface_rotation = "    p := surfPath rotated -hatchAngle;"
    if source.count(flat_surface_rotation) != 1:
        raise ValueError("expected one flatSurface source rotation")
    source = source.replace(
        flat_surface_rotation,
        '    traceFlatClip := (str @# = "") or (str @# = "hatches");\n'
        + flat_surface_rotation,
    )
    flat_surface_end = (
        "    clip hatchImage to surfPath;\n"
        "    image(\n"
        "        draw hatchImage;\n"
        "    )\n"
        "enddef;"
    )
    if source.count(flat_surface_end) != 1:
        raise ValueError("expected one flatSurface return block")
    source = source.replace(flat_surface_end, flat_surface_end.replace(
        "    image(", "    traceFlatClip := false;\n    image("))
    rotate_anchor = "                aHatch := aHatch rotated hatchAngle;"
    if source.count(rotate_anchor) != 1:
        raise ValueError(f"expected one flatSurface hatch rotation, found {source.count(rotate_anchor)}")
    source = source.replace(rotate_anchor, rotate_anchor + '''
                if traceFlatClip:
                    traceHatchRow := i;
                    traceHatchBpRecord(100, point 0 of aHatch);
                    traceHatchBpRecord(101, postcontrol 0 of aHatch);
                    traceHatchBpRecord(102, precontrol 1 of aHatch);
                    traceHatchBpRecord(103, point 1 of aHatch);
                    traceClipPoint("S104-CLIP-ROT", i, 0, point 0 of aHatch);
                    traceClipPoint("S104-CLIP-ROT", i, 1, point 1 of aHatch);
                fi;''')
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
        "traceHatchRow := i;\n"
        "traceSubdivisionDraw := uniformdeviate(2);\n"
        "traceSubdivisions := 3+round(traceSubdivisionDraw);\n"
        "                aHatch := pathSubdivide(aHatch,traceSubdivisions);\n"
        '                message "S104-SUBDRAW " & decimal(i) & " "'
        ' & decimal(traceSubdivisionDraw) & " " & decimal(traceRngAbsolute);\n'
        "                message \"FSSUB \" & decimal(arclength(aHatch)) & \" \""
        " & decimal(length(aHatch)) & \" \" & decimal(traceSubdivisions);",
    )
    source = source.replace(
        ' & decimal(length(aHatch)) & " " & decimal(traceSubdivisions);',
        ' & decimal(length(aHatch)) & " " & decimal(traceSubdivisions);\n'
        '                if abs(i + 6.37912) < 0.00001:\n'
        '                    for traceHatchPoint := 0 step 1 until length(aHatch):\n'
        '                        traceHatchPointRecord(traceHatchPoint, point traceHatchPoint of aHatch);\n'
                        '                        traceHatchBpRecord(traceHatchPoint, point traceHatchPoint of aHatch);\n'
        '                        if traceHatchPoint < length(aHatch):\n'
        '                            traceHatchControlRecord("S104-HATCHPOST", traceHatchPoint, postcontrol traceHatchPoint of aHatch);\n'
        '                            traceHatchControlRecord("S104-HATCHPRE", traceHatchPoint, precontrol (traceHatchPoint + 1) of aHatch);\n'
        '                        fi;\n'
        '                        traceHatchArcRecord(traceHatchPoint, arclength(subpath(0,traceHatchPoint) of aHatch));\n'
        '                    endfor;\n'
        '                fi;',
    )
    row_distance = f"abs(i - {path_cubic_rows[0]:.5f})"
    for row in path_cubic_rows[1:]:
        row_distance = f"min({row_distance}, abs(i - {row:.5f}))"
    row_condition = f"{row_distance} < 0.00001"
    source = source.replace(
        "if abs(i + 6.37912) < 0.00001:",
        f"if {row_condition}:", 1
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
numeric traceRngAbsolute;
traceRngAbsolute := 0;
numeric traceSubdivisionDraw;
traceSubdivisionDraw := 0;
numeric traceSubdivisions;
traceSubdivisions := 0;
boolean traceFlatHatch;
boolean traceThinCutActive;
boolean traceFlatClip;
numeric traceHatchRow;
numeric traceThinSerial;
numeric traceCutSerial;
numeric traceHatchPoint;
numeric traceClipIndex;
pair traceClipForward, traceClipReverse;
path traceClipInput;
traceFlatHatch := false;
traceThinCutActive := false;
traceFlatClip := false;
traceHatchRow := 0;
traceThinSerial := 0;
traceCutSerial := 0;
vardef traceClipPoint (expr tag, row, index, z) =
    save xw, xh, xl, yw, yh, yl;
    numeric xw, xh, xl, yw, yh, yl;
    xw := floor(xpart z);
    xh := floor((xpart z - xw) * 256);
    xl := round(((xpart z - xw) * 256 - xh) * 256);
    yw := floor(ypart z);
    yh := floor((ypart z - yw) * 256);
    yl := round(((ypart z - yw) * 256 - yh) * 256);
    message tag & " " & decimal(row) & " " & decimal(index) & " "
        & decimal(xw) & " " & decimal(xh) & " " & decimal(xl) & " "
        & decimal(yw) & " " & decimal(yh) & " " & decimal(yl);
enddef;
vardef traceClipPair (expr tag, row, a, b) =
    save aw, ah, al, bw, bh, bl;
    numeric aw, ah, al, bw, bh, bl;
    aw := floor(a);
    ah := floor((a - aw) * 256);
    al := round(((a - aw) * 256 - ah) * 256);
    bw := floor(b);
    bh := floor((b - bw) * 256);
    bl := round(((b - bw) * 256 - bh) * 256);
    message tag & " " & decimal(row) & " "
        & decimal(aw) & " " & decimal(ah) & " " & decimal(al) & " "
        & decimal(bw) & " " & decimal(bh) & " " & decimal(bl);
enddef;
vardef traceHatchPointRecord (expr index, z) =
    save xw, xh, xl, yw, yh, yl;
    numeric xw, xh, xl, yw, yh, yl;
    xw := floor(xpart z / mm);
    xh := floor((xpart z / mm - xw) * 256);
    xl := round(((xpart z / mm - xw) * 256 - xh) * 256);
    yw := floor(ypart z / mm);
    yh := floor((ypart z / mm - yw) * 256);
    yl := round(((ypart z / mm - yw) * 256 - yh) * 256);
    message "S104-HATCHPT " & decimal(traceHatchRow) & " " & decimal(index) & " "
        & decimal(xw) & " " & decimal(xh) & " " & decimal(xl) & " "
        & decimal(yw) & " " & decimal(yh) & " " & decimal(yl);
enddef;
vardef traceHatchArcRecord (expr index, arc) =
    save aw, ah, al;
    numeric aw, ah, al;
    aw := floor(arc);
    ah := floor((arc - aw) * 256);
    al := round(((arc - aw) * 256 - ah) * 256);
    message "S104-HATCHARC " & decimal(traceHatchRow) & " " & decimal(index) & " "
        & decimal(aw) & " " & decimal(ah) & " " & decimal(al);
enddef;
vardef traceHatchBpRecord (expr index, z) =
    save xw, xh, xl, yw, yh, yl;
    numeric xw, xh, xl, yw, yh, yl;
    xw := floor(xpart z);
    xh := floor((xpart z - xw) * 256);
    xl := round(((xpart z - xw) * 256 - xh) * 256);
    yw := floor(ypart z);
    yh := floor((ypart z - yw) * 256);
    yl := round(((ypart z - yw) * 256 - yh) * 256);
    message "S104-HATCHBP " & decimal(traceHatchRow) & " " & decimal(index) & " "
        & decimal(xw) & " " & decimal(xh) & " " & decimal(xl) & " "
        & decimal(yw) & " " & decimal(yh) & " " & decimal(yl);
enddef;
vardef traceHatchControlRecord (expr tag, index, z) =
    save xw, xh, xl, yw, yh, yl;
    numeric xw, xh, xl, yw, yh, yl;
    xw := floor(xpart z);
    xh := floor((xpart z - xw) * 256);
    xl := round(((xpart z - xw) * 256 - xh) * 256);
    yw := floor(ypart z);
    yh := floor((ypart z - yw) * 256);
    yl := round(((ypart z - yw) * 256 - yh) * 256);
    message tag & " " & decimal(traceHatchRow) & " " & decimal(index) & " "
        & decimal(xw) & " " & decimal(xh) & " " & decimal(xl) & " "
        & decimal(yw) & " " & decimal(yh) & " " & decimal(yl);
enddef;
vardef traceUniformdeviate (expr x) =
    traceRngTotal := traceRngTotal + 1;
    traceRngAbsolute := traceRngAbsolute + 1;
    if traceRngAbsolute >= 4000: traceRngAbsolute := traceRngAbsolute - 4000; fi;
    uniformdeviate(x)
enddef;
"""
    row_distance = f"abs(traceHatchRow - {path_cubic_rows[0]:.5f})"
    for row in path_cubic_rows[1:]:
        row_distance = f"min({row_distance}, abs(traceHatchRow - {row:.5f}))"
    condition = f"{row_distance} < 0.00001"
    source = source.replace(
        "if traceHatchRow = -6.37912:", f"if {condition}:", 1
    )
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
