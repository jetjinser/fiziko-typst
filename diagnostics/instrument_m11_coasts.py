#!/usr/bin/env python3
"""Trace RNG calls by shading stage and coast in a pinned M11 source copy."""

import re
import sys
from pathlib import Path


def replace_once(source: str, old: str, new: str, name: str) -> str:
    count = source.count(old)
    if count != 1:
        raise ValueError(f"expected one {name} hook, found {count}")
    return source.replace(old, new)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: instrument_m11_coasts.py UPSTREAM_FIZIKO_MP OUTPUT_MP")
    source = Path(sys.argv[1]).read_text()
    source = replace_once(
        source,
        "        p1 := image(draw sphereLat(2s, lat));",
        '        traceCoastRng := 0;\n'
        '        p1 := image(draw sphereLat(2s, lat));\n'
        '        message "M11-P1 " & decimal(traceCoastRng);',
        "p1 shading",
    )
    source = replace_once(
        source,
        "        p2 := image(draw sphereLat(2s, lat));",
        '        traceCoastRng := 0;\n'
        '        p2 := image(draw sphereLat(2s, lat));\n'
        '        message "M11-P2 " & decimal(traceCoastRng);',
        "p2 shading",
    )
    coast = """            thinBrushGenerate (lm,
                offsetPathTemplate (lm, 0) (
                    2/3minStrokeWidth + 1/3minStrokeWidth
                    * normalVectorToLightness(
                        sphereAnglesToNormalVector(
                            (angleRad(point offsetPathTime of lm), arcsin(abs(point offsetPathTime of lm)/2s))
                        ), 0, point offsetPathTime of lm
                    )
                ), 0);
"""
    source = replace_once(
        source,
        coast,
        '            message "M11-COAST-BEGIN " & decimal(i);\n'
        "            traceCoastWidth := true;\n"
        "            traceCoastRng := 0;\n"
        + coast
        + "            traceCoastWidth := false;\n"
        + '            message "M11-COAST " & decimal(i) & " " & decimal(traceCoastRng);\n'
        + '            message "M11-COAST-END " & decimal(i);\n',
        "coast brush",
    )
    source = re.sub(r"\buniformdeviate\s*\(", "traceUniformdeviate(", source)
    source += """

numeric traceCoastRng;
traceCoastRng := 0;
vardef traceUniformdeviate (expr x) =
    traceCoastRng := traceCoastRng + 1;
    uniformdeviate(x)
enddef;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
