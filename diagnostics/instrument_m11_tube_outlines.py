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
                    message "M11TS " & decimal(traceBoundaryCall) & " "
                        & decimal(i) & " " & decimal(j)
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
    boundary_anchor = "    tubeOutline := q3--reverse(q2)--cycle;"
    if source.count(boundary_anchor) != 1:
        raise ValueError(f"expected one tube boundary hook, found {source.count(boundary_anchor)}")
    boundary_trace = boundary_anchor + '''
    if traceKnotActive:
        traceBoundaryCall := traceBoundaryCall + 1;
        for traceCurveIndex := 0 step 1 until length(q2) - 1:
            message "M11EDGECURVEA " & decimal(traceCurveIndex) & " 2 "
                & decimal(xpart(point traceCurveIndex of q2)/mm) & " "
                & decimal(ypart(point traceCurveIndex of q2)/mm) & " "
                & decimal(xpart(postcontrol traceCurveIndex of q2)/mm) & " "
                & decimal(ypart(postcontrol traceCurveIndex of q2)/mm);
            message "M11EDGECURVEB " & decimal(traceCurveIndex) & " 2 "
                & decimal(xpart(precontrol (traceCurveIndex+1) of q2)/mm) & " "
                & decimal(ypart(precontrol (traceCurveIndex+1) of q2)/mm) & " "
                & decimal(xpart(point (traceCurveIndex+1) of q2)/mm) & " "
                & decimal(ypart(point (traceCurveIndex+1) of q2)/mm);
            message "M11EDGECURVEA " & decimal(traceCurveIndex) & " 3 "
                & decimal(xpart(point traceCurveIndex of q3)/mm) & " "
                & decimal(ypart(point traceCurveIndex of q3)/mm) & " "
                & decimal(xpart(postcontrol traceCurveIndex of q3)/mm) & " "
                & decimal(ypart(postcontrol traceCurveIndex of q3)/mm);
            message "M11EDGECURVEB " & decimal(traceCurveIndex) & " 3 "
                & decimal(xpart(precontrol (traceCurveIndex+1) of q3)/mm) & " "
                & decimal(ypart(precontrol (traceCurveIndex+1) of q3)/mm) & " "
                & decimal(xpart(point (traceCurveIndex+1) of q3)/mm) & " "
                & decimal(ypart(point (traceCurveIndex+1) of q3)/mm);
        endfor;
        for traceBoundaryTime := 0 step 1/4 until length(q2):
            message "M11EDGE " & decimal(traceBoundaryCall) & " 2 "
                & decimal(traceBoundaryTime/4) & " "
                & decimal(xpart(point traceBoundaryTime of q2)/mm) & " "
                & decimal(ypart(point traceBoundaryTime of q2)/mm) & " "
                & decimal(angle(direction traceBoundaryTime of q2));
            message "M11EDGE " & decimal(traceBoundaryCall) & " 3 "
                & decimal(traceBoundaryTime/4) & " "
                & decimal(xpart(point traceBoundaryTime of q3)/mm) & " "
                & decimal(ypart(point traceBoundaryTime of q3)/mm) & " "
                & decimal(angle(direction traceBoundaryTime of q3));
        endfor;
    fi;'''
    source = source.replace(boundary_anchor, boundary_trace)
    tube_start = "vardef tubeGenerate@#(expr p, q, d, i) ="
    if source.count(tube_start) != 1:
        raise ValueError(f"expected one tubeGenerate hook, found {source.count(tube_start)}")
    source = source.replace(tube_start,
        tube_start + "\n    if traceKnotActive: traceTubeCall := traceTubeCall + 1; fi;")
    lane_start = "                    brushGenerate (currentPath,\n                    offsetPathTemplate(currentPath, 0)("
    if source.count(lane_start) != 1:
        raise ValueError(f"expected one tube lane brush hook, found {source.count(lane_start)}")
    source = source.replace(lane_start,
        "                    if traceKnotActive: traceLaneStart := traceKnotRng; traceCurrentK := k; fi;\n"
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
    brush_width = "    w1 := (ypart(lrcorner(bt)));"
    if source.count(brush_width) != 1:
        raise ValueError(f"expected one brush width hook, found {source.count(brush_width)}")
    source = source.replace(brush_width, brush_width + '''
    if traceKnotActive:
        message "M11BW " & decimal(traceTubeCall) & " " & decimal(traceCurrentK)
            & " " & decimal(w0) & " " & decimal(w1) & " " & decimal(arclength(p)/mm);
    fi;''')
    shadow_hit = "            if q isInside shiftedShadowPath:"
    if source.count(shadow_hit) != 1:
        raise ValueError(f"expected one lighting shadow test, found {source.count(shadow_hit)}")
    source = source.replace(shadow_hit, shadow_hit + '''
                if traceKnotActive:
                    message "M11SHADOW " & decimal(traceTubeCall) & " "
                        & decimal(traceCurrentK) & " "
                        & decimal(xpart(q)/mm) & " " & decimal(ypart(q)/mm);
                fi;''')
    light_return = "    returnValue\nenddef;\n\nvardef lightnessPP"
    if source.count(light_return) != 1:
        raise ValueError(f"expected one lightness return hook, found {source.count(light_return)}")
    source = source.replace(light_return, '''    if traceKnotActive:
        message "M11WIDTHINPUT " & decimal(traceTubeCall) & " "
            & decimal(traceCurrentK) & " " & decimal(bw1) & " "
            & decimal(offsetPathTime) & " " & decimal(maxShadingStrokeWidth/mm)
            & " " & decimal(lineDensity/mm) & " "
            & decimal(ypart(point offsetPathTime of tubeWidth)/mm);
        message "M11LIGHT " & decimal(traceTubeCall) & " "
            & decimal(traceCurrentK) & " " & decimal(xpart(q)/mm) & " "
            & decimal(ypart(q)/mm) & " " & decimal(redpart(normalVector)) & " "
            & decimal(greenpart(normalVector)) & " " & decimal(bluepart(normalVector))
            & " " & decimal(returnValue);
    fi;
    returnValue
enddef;

vardef lightnessPP''')
    normal_return = "    normalVector := rotateXYZaround.z(normalVector, -greenpart(p));\n    normalVector\nenddef;"
    if source.count(normal_return) != 1:
        raise ValueError(f"expected one tube normal return hook, found {source.count(normal_return)}")
    source = source.replace(normal_return, '''    normalVector := rotateXYZaround.z(normalVector, -greenpart(p));
    if traceKnotActive:
        message "M11ANGLE " & decimal(traceTubeCall) & " "
            & decimal(traceCurrentK) & " " & decimal(redpart(p)) & " "
            & decimal(greenpart(p)) & " " & decimal(bluepart(p)) & " "
            & decimal(redpart(normalVector)) & " " & decimal(greenpart(normalVector))
            & " " & decimal(bluepart(normalVector));
    fi;
    normalVector
enddef;''')
    thin_start = "    w1 := ypart(lrcorner(bt));"
    if source.count(thin_start) != 1:
        raise ValueError(f"expected one thin-brush width hook, found {source.count(thin_start)}")
    source = source.replace(thin_start, thin_start + '''
    if traceKnotActive:
        message "M11THIN " & decimal(traceTubeCall) & " "
            & decimal(traceCurrentK) & " " & decimal(i) & " "
            & decimal(w0/mm) & " " & decimal(w1/mm) & " "
            & decimal(arclength(p)/mm);
    fi;''')
    thin_cut = "        t := cutPathTime(bt, w2);"
    if source.count(thin_cut) != 1:
        raise ValueError(f"expected one thin-brush cut hook, found {source.count(thin_cut)}")
    source = source.replace(thin_cut, thin_cut + '''
        if traceKnotActive:
            message "M11TCUT " & decimal(traceTubeCall) & " "
                & decimal(traceCurrentK) & " " & decimal(i) & " "
                & decimal(w2/mm) & " " & decimal(t);
        fi;''')
    thin_dash = "                    draw p withpen thinpen dashed thinBrushPattern(w2, arclength(p));"
    if source.count(thin_dash) != 1:
        raise ValueError(f"expected one thin-brush dash hook, found {source.count(thin_dash)}")
    source = source.replace(thin_dash, '''                    if traceKnotActive:
                        message "M11DASH " & decimal(traceTubeCall) & " "
                            & decimal(traceCurrentK) & " " & decimal(i) & " "
                            & decimal(w2/mm) & " " & decimal(arclength(p)/mm) & " "
                            & decimal(xpart(point 0 of p)/mm) & " "
                            & decimal(ypart(point 0 of p)/mm) & " "
                            & decimal(xpart(point length(p) of p)/mm) & " "
                            & decimal(ypart(point length(p) of p)/mm);
                    fi;
                    draw p withpen thinpen dashed thinBrushPattern(w2, arclength(p));''')
    current_path = "                currentPath := interpath (k/bw1, q, p);"
    if source.count(current_path) != 1:
        raise ValueError(f"expected one tube lane path hook, found {source.count(current_path)}")
    source = source.replace(current_path, current_path + '''
                if traceKnotActive:
                    if (k = 2) or (k = 6) or (k = 8):
                        message "M11PARAM " & decimal(traceTubeCall) & " "
                            & decimal(k) & " " & decimal(length(currentPath)) & " "
                            & decimal(length(currentTubePath)) & " " & decimal(length(tubeWidth));
                    fi;
                    if (k = 2) or (k = 6) or (k = 8):
                        for traceCurveIndex := 0 step 1 until length(currentPath) - 1:
                            message "M11CURVEA " & decimal(traceTubeCall) & " "
                                & decimal(k) & " " & decimal(traceCurveIndex) & " "
                                & decimal(xpart(point traceCurveIndex of currentPath)/mm) & " "
                                & decimal(ypart(point traceCurveIndex of currentPath)/mm) & " "
                                & decimal(xpart(postcontrol traceCurveIndex of currentPath)/mm) & " "
                                & decimal(ypart(postcontrol traceCurveIndex of currentPath)/mm);
                            message "M11CURVEB " & decimal(traceTubeCall) & " "
                                & decimal(k) & " " & decimal(traceCurveIndex) & " "
                                & decimal(xpart(precontrol (traceCurveIndex+1) of currentPath)/mm) & " "
                                & decimal(ypart(precontrol (traceCurveIndex+1) of currentPath)/mm) & " "
                                & decimal(xpart(point (traceCurveIndex+1) of currentPath)/mm) & " "
                                & decimal(ypart(point (traceCurveIndex+1) of currentPath)/mm);
                        endfor;
                    fi;
                fi;''')
    current_tube_path = "            currentTubePath := interpath (1/2, q, p);"
    if source.count(current_tube_path) != 1:
        raise ValueError(f"expected one tube centerline hook, found {source.count(current_tube_path)}")
    source = source.replace(current_tube_path, current_tube_path + '''
            if traceKnotActive:
                for traceCurveIndex := 0 step 1 until length(currentTubePath) - 1:
                    message "M11CENTERA " & decimal(traceTubeCall) & " "
                        & decimal(traceCurveIndex) & " "
                        & decimal(xpart(point traceCurveIndex of currentTubePath)/mm) & " "
                        & decimal(ypart(point traceCurveIndex of currentTubePath)/mm) & " "
                        & decimal(xpart(postcontrol traceCurveIndex of currentTubePath)/mm) & " "
                        & decimal(ypart(postcontrol traceCurveIndex of currentTubePath)/mm);
                    message "M11CENTERB " & decimal(traceTubeCall) & " "
                        & decimal(traceCurveIndex) & " "
                        & decimal(xpart(precontrol (traceCurveIndex+1) of currentTubePath)/mm) & " "
                        & decimal(ypart(precontrol (traceCurveIndex+1) of currentTubePath)/mm) & " "
                        & decimal(xpart(point (traceCurveIndex+1) of currentTubePath)/mm) & " "
                        & decimal(ypart(point (traceCurveIndex+1) of currentTubePath)/mm);
                endfor;
            fi;''')
    knot_start = "    totalNumberOfSegments := 0;\n    for sNa := 1 step 1 until knotName.nStrands:"
    if source.count(knot_start) != 1:
        raise ValueError(f"expected one knot start hook, found {source.count(knot_start)}")
    source = source.replace(knot_start,
        "    totalNumberOfSegments := 0;\n"
        "    traceKnotRng := 0;\n"
        "    traceTubeCall := 0;\n"
        "    traceBoundaryCall := 0;\n"
        "    traceKnotActive := true;\n"
        '    message "M11TSTART " & decimal(traceCallBlocks) & " "'
        ' & decimal(traceCallRemainder);\n'
        "    for sNa := 1 step 1 until knotName.nStrands:")
    # MetaPost permits implicit multiplication, as in `1/2uniformdeviate(...)`;
    # a word-boundary matcher misses that call because the preceding `2` is a
    # word character. Match any non-letter prefix instead.
    source = re.sub(r"(?<![A-Za-z])uniformdeviate\s*\(", "traceKnotDeviate(", source)
    source += """
numeric traceMaskTime, traceBoundaryTime, traceCurveIndex, traceBoundaryCall, traceKnotRng, traceLaneStart, traceTubeCall, traceCurrentK;
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
