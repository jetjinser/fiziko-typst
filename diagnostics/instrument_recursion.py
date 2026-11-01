#!/usr/bin/env python3
"""Instrument source brush recursion nodes for a focused MetaPost trace.

Usage: instrument_recursion.py UPSTREAM_FIZIKO_MP OUTPUT_MP
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
        "                    currentPath := offsetPathSubdivide(currentPath);",
        "                    currentPath := offsetPathSubdivide(currentPath);\n"
        '                    message "LAT=" & decimal(nline) & " SPH=" & decimal(sphlat);',
    )

    source = replace_once(
        source,
        "    w1 := (ypart(lrcorner(bt)));\n"
        "    t := cutPathTime(bt, minStrokeWidth);",
        "    w1 := (ypart(lrcorner(bt)));\n"
        '    message "RN O " & decimal(i) & " "'
        ' & decimal(ypart(lrcorner(bt))) & " " & decimal(ypart(urcorner(bt)))'
        ' & " " & decimal(arclength(p));\n'
        "    t := cutPathTime(bt, minStrokeWidth);\n"
        '    message "RC O " & decimal(i) & " " & decimal(t)'
        ' & " " & decimal(arclength(p));\n'
        "    if (t >= 0) and (t <= length(p)):\n"
        '        message "RL O " & decimal(i) & " "'
        ' & decimal(arclength(subpath (0, t) of p)) & " "'
        ' & decimal(arclength(subpath (t, length(p)) of p));\n'
        "    else:\n"
        '        message "RL O " & decimal(i) & " -1 -1";\n'
        "    fi;",
    )
    source = replace_once(
        source,
        "        brushGenerate (subpath (0, t) of p, subpath (0, t) of q, i + 1);",
        '        message "RS O " & decimal(i);\n'
        "        brushGenerate (subpath (0, t) of p, subpath (0, t) of q, i + 1);",
    )

    source = replace_once(
        source,
        "    w0 := ypart(urcorner(bt));\n"
        "    w1 := ypart(lrcorner(bt));",
        "    w0 := ypart(urcorner(bt));\n"
        "    w1 := ypart(lrcorner(bt));\n"
        '    message "RN T " & decimal(i) & " "'
        ' & decimal(ypart(lrcorner(bt))) & " "'
        ' & decimal(ypart(urcorner(bt))) & " " & decimal(arclength(p));',
    )
    source = replace_once(
        source,
        "        t := cutPathTime(bt, w2);",
        "        t := cutPathTime(bt, w2);\n"
        '        message "RC T " & decimal(i) & " " & decimal(w2)'
        ' & " " & decimal(t) & " " & decimal(arclength(p));\n'
        "        if (t >= 0) and (t <= length(p)):\n"
        '            message "RL T " & decimal(i) & " "'
        ' & decimal(arclength(subpath (0, t) of p)) & " "'
        ' & decimal(arclength(subpath (t, length(p)) of p));\n'
        "        else:\n"
        '            message "RL T " & decimal(i) & " -1 -1";\n'
        "        fi;",
    )
    source = replace_once(
        source,
        "            thinBrushGenerate@#(brushPath1, subpath (0, t) of q, i + 1);",
        '            message "RS T " & decimal(i);\n'
        "            thinBrushGenerate@#(brushPath1, subpath (0, t) of q, i + 1);",
    )

    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
