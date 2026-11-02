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
        '        message "S101 CUT " & decimal(i) & " " & decimal(w2)'
        ' & " " & decimal(t) & " " & decimal(arclength(brushPath1))'
        ' & " " & decimal(arclength(brushPath2));',
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
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
