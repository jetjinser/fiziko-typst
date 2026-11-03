#!/usr/bin/env python3
"""Trace thin-brush recursion, RNG, and q cubic controls in a fiziko.mp copy.

Usage: instrument_brush.py UPSTREAM_FIZIKO_MP OUTPUT_MP
"""

import sys
from pathlib import Path


def replace_once(source: str, old: str, new: str) -> str:
    count = source.count(old)
    if count != 1:
        raise ValueError(f"expected one insertion point, found {count}: {old[:72]!r}")
    return source.replace(old, new)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)

    source = Path(sys.argv[1]).read_text()
    source = replace_once(
        source,
        "vardef thinBrushPattern (expr w, l) =\n"
        "    save d;",
        "vardef thinBrushPattern (expr w, l) =\n"
        '    message "S101-DASH " & decimal(w) & " " & decimal(l);\n'
        "    save d;",
    )
    source = replace_once(
        source,
        "    if invertedLight:\n\t\treturnValue := 1 - returnValue;\n\tfi;\n"
        "    returnValue\nenddef;\n\nvardef lightnessPP",
        "    if invertedLight:\n\t\treturnValue := 1 - returnValue;\n\tfi;\n"
        "    if traceCoastWidth:\n"
        '        message "M11-NORMAL " & decimal(redpart(normalVector)) & " "'
        '            & decimal(greenpart(normalVector)) & " "'
        '            & decimal(bluepart(normalVector)) & " "'
        '            & decimal(xpart(q)) & " " & decimal(ypart(q)) & " "'
        '            & decimal(returnValue);\n'
        "    fi;\n"
        "    returnValue\nenddef;\n\nvardef lightnessPP",
    )
    source = replace_once(
        source,
        "                    w2 := 1/3w2;\n"
        "                    if (w2 >= minWidth) and (arclength(p) > 0):",
        "                    w2 := 1/3w2;\n"
        '                    message "S101 TRY";\n'
        "                    if (w2 >= minWidth) and (arclength(p) > 0):\n"
        '                        message "S101 WIDTH " & decimal(w2);\n'
        '                        message "S101 START " & decimal(xpart(point 0 of p))'
        ' & " " & decimal(ypart(point 0 of p));\n'
        '                        message "S101 LENGTH " & decimal(arclength(p));\n'
        '                        message "S101 ENDX " & decimal(xpart(point length(p) of p));\n'
        '                        message "S101 ENDY " & decimal(ypart(point length(p) of p));',
    )
    source = replace_once(
        source,
        "    w0 := ypart(urcorner(bt));\n"
        "    w1 := ypart(lrcorner(bt));",
        "    w0 := ypart(urcorner(bt));\n"
        "    w1 := ypart(lrcorner(bt));\n"
        "    for traceKnotIndex := 0 upto length(bt):\n"
        '        message "S101-QKNOT " & decimal(i) & " "'
        ' & decimal(traceKnotIndex) & " "'
        ' & decimal(xpart(point traceKnotIndex of bt)) & " "'
        ' & decimal(ypart(point traceKnotIndex of bt)) & " "'
        ' & decimal(xpart(point traceKnotIndex of p)) & " "'
        ' & decimal(ypart(point traceKnotIndex of p));\n'
        '        message "S101-QKNOT-FIX " & decimal(i) & " "'
        ' & decimal(traceKnotIndex) & " "'
        ' & traceFixed(xpart(point traceKnotIndex of bt)) & " "'
        ' & traceFixed(ypart(point traceKnotIndex of bt));\n'
        "    endfor;\n"
        '    message "S101 NODE " & decimal(i) & " " & decimal(w0)'
        ' & " " & decimal(w1) & " " & decimal(arclength(p))'
        ' & " " & decimal(length(p)) & " "'
        ' & decimal(xpart(point 0 of p)) & " " & decimal(ypart(point 0 of p))'
        ' & " " & decimal(xpart(point length(p) of p))'
        ' & " " & decimal(ypart(point length(p) of p));',
    )
    source = replace_once(
        source,
        "        t := cutPathTime(bt, w2);\n"
        "        brushPath1 := subpath (0, t) of p;\n"
        "        brushPath2 := subpath (t, length(p)) of p;",
        "        traceCoastDepth := i;\n"
        "        t := cutPathTime(bt, w2);\n"
        "        brushPath1 := subpath (0, t) of p;\n"
        "        brushPath2 := subpath (t, length(p)) of p;\n"
        '        traceCurveIndex := floor(t);\n'
        '        message "S101-CUBIC " & decimal(i) & " "'
        ' & decimal(traceCurveIndex) & " " & decimal(w2) & " " & decimal(t);\n'
        '        message "S101-Q0 " & decimal(i) & " "'
        ' & decimal(xpart(point traceCurveIndex of q)) & " "'
        ' & decimal(ypart(point traceCurveIndex of q));\n'
        '        message "S101-QPOST " & decimal(i) & " "'
        ' & decimal(xpart(postcontrol traceCurveIndex of q)) & " "'
        ' & decimal(ypart(postcontrol traceCurveIndex of q));\n'
        '        message "S101-QPRE " & decimal(i) & " "'
        ' & decimal(xpart(precontrol (traceCurveIndex+1) of q)) & " "'
        ' & decimal(ypart(precontrol (traceCurveIndex+1) of q));\n'
        '        message "S101-Q1 " & decimal(i) & " "'
        ' & decimal(xpart(point (traceCurveIndex+1) of q)) & " "'
        ' & decimal(ypart(point (traceCurveIndex+1) of q));\n'
        '        message "S101-QCTRLPT-FIX " & decimal(i) & " 0 "'
        ' & traceFixed(xpart(point traceCurveIndex of q)) & " "'
        ' & traceFixed(ypart(point traceCurveIndex of q));\n'
        '        message "S101-QCTRLPT-FIX " & decimal(i) & " 1 "'
        ' & traceFixed(xpart(postcontrol traceCurveIndex of q)) & " "'
        ' & traceFixed(ypart(postcontrol traceCurveIndex of q));\n'
        '        message "S101-QCTRLPT-FIX " & decimal(i) & " 2 "'
        ' & traceFixed(xpart(precontrol (traceCurveIndex+1) of q)) & " "'
        ' & traceFixed(ypart(precontrol (traceCurveIndex+1) of q));\n'
        '        message "S101-QCTRLPT-FIX " & decimal(i) & " 3 "'
        ' & traceFixed(xpart(point (traceCurveIndex+1) of q)) & " "'
        ' & traceFixed(ypart(point (traceCurveIndex+1) of q));\n'
        '        message "S101-CUTFIX " & decimal(i) & " "'
        ' & traceFixed(t);\n'
        '        message "S101 CUT " & decimal(i) & " " & decimal(w2)'
        ' & " " & decimal(t) & " " & decimal(arclength(brushPath1))'
        ' & " " & decimal(arclength(brushPath2));',
    )
    source = replace_once(
        source,
        "        d3 := 1/2(d1 + d2);\n"
        "        cutTime1 := ypart(((d3, h) -- (d1, h)) firstIntersectionTimes p);\n"
        "        cutTime2 := ypart(((d3, h) -- (d2, h)) firstIntersectionTimes p);\n"
        "        d4 := xpart (point cutTime1 of p);\n"
        "        d5 := xpart (point cutTime2 of p);",
        "        d3 := 1/2(d1 + d2);\n"
        '        if traceCoastWidth: message "S101-CUTINPUT " & decimal(traceCoastDepth) & " "'
        ' & traceFixed(d1) & " " & traceFixed(d2)'
        ' & " " & traceFixed(d3) & " " & traceFixed(h); fi;\n'
        '        if traceCoastWidth: message "S101-RAY1-FIX " & '
        'traceFixed(xpart(point 0 of ((d3,h)--(d1,h)))) & " " & '
        'traceFixed(ypart(point 0 of ((d3,h)--(d1,h)))) & " " & '
        'traceFixed(xpart(postcontrol 0 of ((d3,h)--(d1,h)))) & " " & '
        'traceFixed(ypart(postcontrol 0 of ((d3,h)--(d1,h)))) & " " & '
        'traceFixed(xpart(precontrol 1 of ((d3,h)--(d1,h)))) & " " & '
        'traceFixed(ypart(precontrol 1 of ((d3,h)--(d1,h)))) & " " & '
        'traceFixed(xpart(point 1 of ((d3,h)--(d1,h)))) & " " & '
        'traceFixed(ypart(point 1 of ((d3,h)--(d1,h)))); fi;\n'
        "        cutTime1 := ypart(((d3, h) -- (d1, h)) firstIntersectionTimes p);\n"
        '        if traceCoastWidth: message "S101-HIT1 " & decimal(traceCoastDepth) & " "'
        ' & traceFixed(cutTime1) & " "'
        ' & traceFixed(xpart(point cutTime1 of p)); fi;\n'
        '        if traceCoastWidth and (cutTime1 >= 0)\n'
        '            and (cutTime1 < length(p)):\n'
        '            message "S101-QX1 " & decimal(traceCoastDepth) & " "'
        ' & decimal(floor(cutTime1)) & " "'
        ' & traceFixed(xpart(point floor(cutTime1) of p)) & " "'
        ' & traceFixed(xpart(postcontrol floor(cutTime1) of p)) & " "'
        ' & traceFixed(xpart(precontrol (floor(cutTime1)+1) of p)) & " "'
        ' & traceFixed(xpart(point (floor(cutTime1)+1) of p));\n'
        '            message "S101-QY1 " & decimal(traceCoastDepth) & " "'
        ' & decimal(floor(cutTime1)) & " "'
        ' & traceFixed(ypart(point floor(cutTime1) of p)) & " "'
        ' & traceFixed(ypart(postcontrol floor(cutTime1) of p)) & " "'
        ' & traceFixed(ypart(precontrol (floor(cutTime1)+1) of p)) & " "'
        ' & traceFixed(ypart(point (floor(cutTime1)+1) of p));\n'
        '        fi;\n'
        "        cutTime2 := ypart(((d3, h) -- (d2, h)) firstIntersectionTimes p);\n"
        '        if traceCoastWidth: message "S101-RAY2-FIX " & '
        'traceFixed(xpart(point 0 of ((d3,h)--(d2,h)))) & " " & '
        'traceFixed(ypart(point 0 of ((d3,h)--(d2,h)))) & " " & '
        'traceFixed(xpart(postcontrol 0 of ((d3,h)--(d2,h)))) & " " & '
        'traceFixed(ypart(postcontrol 0 of ((d3,h)--(d2,h)))) & " " & '
        'traceFixed(xpart(precontrol 1 of ((d3,h)--(d2,h)))) & " " & '
        'traceFixed(ypart(precontrol 1 of ((d3,h)--(d2,h)))) & " " & '
        'traceFixed(xpart(point 1 of ((d3,h)--(d2,h)))) & " " & '
        'traceFixed(ypart(point 1 of ((d3,h)--(d2,h)))); fi;\n'
        '        if traceCoastWidth: message "S101-HIT2 " & decimal(traceCoastDepth) & " "'
        ' & traceFixed(cutTime2) & " "'
        ' & traceFixed(xpart(point cutTime2 of p)); fi;\n'
        '        if traceCoastWidth and (cutTime2 >= 0)\n'
        '            and (cutTime2 < length(p)):\n'
        '            message "S101-QX2 " & decimal(traceCoastDepth) & " "'
        ' & decimal(floor(cutTime2)) & " "'
        ' & traceFixed(xpart(point floor(cutTime2) of p)) & " "'
        ' & traceFixed(xpart(postcontrol floor(cutTime2) of p)) & " "'
        ' & traceFixed(xpart(precontrol (floor(cutTime2)+1) of p)) & " "'
        ' & traceFixed(xpart(point (floor(cutTime2)+1) of p));\n'
        '            message "S101-QY2 " & decimal(traceCoastDepth) & " "'
        ' & decimal(floor(cutTime2)) & " "'
        ' & traceFixed(ypart(point floor(cutTime2) of p)) & " "'
        ' & traceFixed(ypart(postcontrol floor(cutTime2) of p)) & " "'
        ' & traceFixed(ypart(precontrol (floor(cutTime2)+1) of p)) & " "'
        ' & traceFixed(ypart(point (floor(cutTime2)+1) of p));\n'
        '        fi;\n'
        "        d4 := xpart (point cutTime1 of p);\n"
        "        d5 := xpart (point cutTime2 of p);",
    )
    source = replace_once(
        source,
        "            and (t > 1/100) and (t < length(p) - 1/100):\n"
        "            thinBrushGenerate@#(brushPath1, subpath (0, t) of q, i + 1);",
        "            and (t > 1/100) and (t < length(p) - 1/100):\n"
        '            message "S101 RECURSE " & decimal(i);\n'
        "            thinBrushGenerate@#(brushPath1, subpath (0, t) of q, i + 1);",
    )
    source = replace_once(
        source,
        "            thinBrushGenerate@#(brushPath2, subpath (t, length(q)) of q, i + 1);\n"
        "        else:\n"
        "            if (str @# = \"\") or (str @# = \"hatches\"):",
        "            thinBrushGenerate@#(brushPath2, subpath (t, length(q)) of q, i + 1);\n"
        '        else:\n            message "S101 LEAFNODE " & decimal(i);\n'
        "            if (str @# = \"\") or (str @# = \"hatches\"):",
    )
    source = replace_once(
        source,
        "        n := (w*l)/(stippleSize**2);\n        rn := floor(n);",
        "        n := (w*l)/(stippleSize**2);\n"
        "        rn := floor(n);\n"
        '        message "S101 PATTERN";',
    )
    source = replace_once(
        source,
        '        message "S101 PATTERN";',
        '        message "S101 PATTERN";\n'
        '        message "S101 PARAM " & decimal(n) & " " & decimal(rn)'
        ' & " " & decimal(stippleSize) & " " & decimal(l);',
    )
    source = replace_once(
        source,
        "        d1 := uniformdeviate(d0);",
        "        d1 := uniformdeviate(d0);\n"
        '        message "S101 OFF1 " & decimal(d1);',
    )
    source = replace_once(
        source,
        "            d3 := uniformdeviate(d0);",
        "            d3 := uniformdeviate(d0);\n"
        '            message "S101 OFF2 " & decimal(d3);',
    )
    source = replace_once(
        source,
        "        if uniformdeviate(1) < n:\n"
        "            rv := dashpattern (off uniformdeviate(l-ss) on ss off l);\n"
        "        else:\n"
        "            rv := image();\n"
        "        fi;",
        "        d6 := uniformdeviate(1);\n"
        '        message "S101 CHANCE " & decimal(d6);\n'
        "        if d6 < n:\n"
        "            d5 := uniformdeviate(l-ss);\n"
        '            message "S101 SINGLE " & decimal(d5);\n'
        "            rv := dashpattern (off d5 on ss off l);\n"
        "        else:\n"
        '            message "S101 EMPTY";\n'
        "            rv := image();\n"
        "        fi;",
    )
    source += """

boolean traceCoastWidth;
traceCoastWidth := false;
numeric traceCoastDepth;
traceCoastDepth := -1;
vardef traceFixed (expr x) =
    decimal(floor(x)) & ":"
    & decimal(floor((x-floor(x))*256)) & ":"
    & decimal(floor(((x-floor(x))*256
        - floor((x-floor(x))*256))*256))
enddef;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
