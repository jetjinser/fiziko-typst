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
    if len(sys.argv) not in (3, 4) or (len(sys.argv) == 4 and sys.argv[3] != "--path-cubics"):
        raise SystemExit("usage: instrument_m11_coasts.py UPSTREAM_FIZIKO_MP OUTPUT_MP [--path-cubics]")
    trace_path_cubics = len(sys.argv) == 4
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
    path_trace = ""
    if trace_path_cubics:
        path_trace = '''            if i = 4:
                message "M11-PATHLEN " & decimal(i) & " " & decimal(length(lm));
                for tracePathSegment = 0 upto floor(length(lm))-1:
                    message "M11-PATHC " & decimal(i) & " " & decimal(tracePathSegment) & " "
                        & decimal(xpart(point tracePathSegment of lm)) & " "
                        & decimal(ypart(point tracePathSegment of lm)) & " "
                        & decimal(xpart(postcontrol tracePathSegment of lm)) & " "
                        & decimal(ypart(postcontrol tracePathSegment of lm)) & " "
                        & decimal(xpart(precontrol (tracePathSegment+1) of lm)) & " "
                        & decimal(ypart(precontrol (tracePathSegment+1) of lm)) & " "
                        & decimal(xpart(point (tracePathSegment+1) of lm)) & " "
                        & decimal(ypart(point (tracePathSegment+1) of lm));
                endfor;
            fi;
'''
    source = replace_once(
        source,
        coast,
        '            message "M11-COAST-BEGIN " & decimal(i);\n'
        "            traceCoastWidth := true;\n"
        "            traceCoastRng := 0;\n"
        + path_trace
        + coast
        + "            traceCoastWidth := false;\n"
        + '            message "M11-COAST " & decimal(i) & " " & decimal(traceCoastRng);\n'
        + '            message "M11-COAST-END " & decimal(i);\n',
        "coast brush",
    )
    # MetaPost allows implicit multiplication before a function name, as in
    # `1/2uniformdeviate(d1)`. A word boundary misses that call because the
    # preceding `2` and the `u` are both word characters.
    source = re.sub(r"(?<![A-Za-z_])uniformdeviate\s*\(",
                    "traceUniformdeviate(", source)
    source += """

numeric traceCoastRng;
boolean traceCoastWidth;
traceCoastRng := 0;
traceCoastWidth := false;
vardef traceUniformdeviate (expr x) =
    traceCoastRng := traceCoastRng + 1;
    uniformdeviate(x)
enddef;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
