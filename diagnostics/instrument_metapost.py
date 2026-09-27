#!/usr/bin/env python3
"""Add Figure 12 latitude diagnostics to a copy of upstream fiziko.mp.

Usage: instrument_metapost.py UPSTREAM_FIZIKO_MP OUTPUT_MP
The upstream file is available from https://github.com/jemmybutton/fiziko.
"""

import sys
from pathlib import Path


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f"expected one insertion point, found {source.count(old)}: {old[:60]}")
    return source.replace(old, new)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source = Path(sys.argv[1]).read_text()
    source = replace_once(
        source,
        "    t := cutPathTime(bt, minStrokeWidth);",
        '    if i = 0:\n'
        '        message "BR l=" & decimal(arclength(p)) & " min=" & decimal(w1) & " max=" & decimal(w0);\n'
        '        for diagnosticIndex = 0 upto length(q):\n'
        '            message "BW x=" & decimal(xpart(point diagnosticIndex of q))'
        ' & " w=" & decimal(ypart(point diagnosticIndex of q));\n'
        '        endfor;\n'
        '    fi;\n'
        "    t := cutPathTime(bt, minStrokeWidth);",
    )
    source = replace_once(
        source,
        "            brushPath1 := offsetPathGenerate (p, q yscaled 1/2, 0);",
        '            message "OL solid";\n'
        "            brushPath1 := offsetPathGenerate (p, q yscaled 1/2, 0);",
    )
    source = replace_once(
        source,
        "            thinBrushGenerate (p, q, 0)",
        '            message "OL thin";\n'
        "            thinBrushGenerate (p, q, 0)",
    )
    source = replace_once(
        source,
        "                if (w2 >= minWidth) and (arclength(p) > 0):\n"
        "                    if (w2 < minStrokeWidth)",
        "                if (w2 >= minWidth) and (arclength(p) > 0):\n"
        '                    message "TL";\n'
        "                    if (w2 < minStrokeWidth)",
    )
    source = replace_once(
        source,
        "    d0 := w;\n    if d0 > minStrokeWidth:",
        '    message "TB w=" & decimal(w) & " l=" & decimal(l);\n'
        "    d0 := w;\n    if d0 > minStrokeWidth:",
    )
    source = replace_once(
        source,
        "                    currentPath := offsetPathSubdivide(currentPath);",
        "                    currentPath := offsetPathSubdivide(currentPath);\n"
        '                    message "LAT=" & decimal(nline) & " SPH=" & decimal(sphlat);',
    )
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
