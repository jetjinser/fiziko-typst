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
    path_cubic_ids = (4,)
    trace_path_cubics = len(sys.argv) == 4
    if len(sys.argv) not in (3, 4):
        raise SystemExit("usage: instrument_m11_coasts.py UPSTREAM_FIZIKO_MP OUTPUT_MP [--path-cubics[=IDS]]")
    if len(sys.argv) == 4:
        if sys.argv[3] == "--path-cubics":
            path_cubic_ids = (4,)
        elif sys.argv[3].startswith("--path-cubics="):
            path_cubic_ids = tuple(int(value) for value in sys.argv[3].split("=", 1)[1].split(","))
            if not path_cubic_ids or any(value < 1 or value > 8 for value in path_cubic_ids):
                raise SystemExit("path-cubic IDs must be source landmass IDs 1 through 8")
        else:
            raise SystemExit("usage: instrument_m11_coasts.py UPSTREAM_FIZIKO_MP OUTPUT_MP [--path-cubics[=IDS]]")
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
        path_trace = "\n".join(f'''            if i = {value}:
                message "M11-PATHLEN " & decimal(i) & " " & decimal(length(lm));
                for tracePathSegment = 0 upto floor(length(lm))-1:
                    message "M11-PATHP-FIX " & decimal(i) & " " & decimal(tracePathSegment) & " 0 "
                        & traceFixed(xpart(point tracePathSegment of lm)) & " "
                        & traceFixed(ypart(point tracePathSegment of lm));
                    message "M11-PATHP-FIX " & decimal(i) & " " & decimal(tracePathSegment) & " 1 "
                        & traceFixed(xpart(postcontrol tracePathSegment of lm)) & " "
                        & traceFixed(ypart(postcontrol tracePathSegment of lm));
                    message "M11-PATHP-FIX " & decimal(i) & " " & decimal(tracePathSegment) & " 2 "
                        & traceFixed(xpart(precontrol (tracePathSegment+1) of lm)) & " "
                        & traceFixed(ypart(precontrol (tracePathSegment+1) of lm));
                    message "M11-PATHP-FIX " & decimal(i) & " " & decimal(tracePathSegment) & " 3 "
                        & traceFixed(xpart(point (tracePathSegment+1) of lm)) & " "
                        & traceFixed(ypart(point (tracePathSegment+1) of lm));
                endfor;
            fi;
''' for value in path_cubic_ids)
    source = replace_once(
        source,
        coast,
        '            message "M11-COAST-BEGIN " & decimal(i);\n'
        "            traceCoastWidth := true;\n"
        "            traceCoastRng := 0;\n"
        + path_trace
        + "            traceCoastRootQ := offsetPathTemplate(lm, 0)(\n"
        + "                2/3minStrokeWidth + 1/3minStrokeWidth\n"
        + "                * normalVectorToLightness(\n"
        + "                    sphereAnglesToNormalVector(\n"
        + "                        (angleRad(point offsetPathTime of lm), arcsin(abs(point offsetPathTime of lm)/2s))\n"
        + "                    ), 0, point offsetPathTime of lm\n"
        + "                )\n"
        + "            );\n"
        + "            for traceCoastRootIndex := 0 upto length(traceCoastRootQ):\n"
        + '                message "M11-ROOTQ " & decimal(i) & " " & decimal(traceCoastRootIndex) & " "\n'
        + '                    & traceFixed(xpart(point traceCoastRootIndex of traceCoastRootQ)) & " "\n'
        + '                    & traceFixed(ypart(point traceCoastRootIndex of traceCoastRootQ));\n'
        + '                if traceCoastRootIndex < length(traceCoastRootQ):\n'
        + '                    message "M11-ROOTQC " & decimal(i) & " " & decimal(traceCoastRootIndex) & " 0 "\n'
        + '                        & traceFixed(xpart(point traceCoastRootIndex of traceCoastRootQ)) & " "\n'
        + '                        & traceFixed(ypart(point traceCoastRootIndex of traceCoastRootQ));\n'
        + '                    message "M11-ROOTQC " & decimal(i) & " " & decimal(traceCoastRootIndex) & " 1 "\n'
        + '                        & traceFixed(xpart(postcontrol traceCoastRootIndex of traceCoastRootQ)) & " "\n'
        + '                        & traceFixed(ypart(postcontrol traceCoastRootIndex of traceCoastRootQ));\n'
        + '                    message "M11-ROOTQC " & decimal(i) & " " & decimal(traceCoastRootIndex) & " 2 "\n'
        + '                        & traceFixed(xpart(precontrol (traceCoastRootIndex + 1) of traceCoastRootQ)) & " "\n'
        + '                        & traceFixed(ypart(precontrol (traceCoastRootIndex + 1) of traceCoastRootQ));\n'
        + '                    message "M11-ROOTQC " & decimal(i) & " " & decimal(traceCoastRootIndex) & " 3 "\n'
        + '                        & traceFixed(xpart(point (traceCoastRootIndex + 1) of traceCoastRootQ)) & " "\n'
        + '                        & traceFixed(ypart(point (traceCoastRootIndex + 1) of traceCoastRootQ));\n'
        + '                fi;\n'
        + "            endfor;\n"
        + "            thinBrushGenerate(lm, traceCoastRootQ, 0);\n"
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
path traceCoastRootQ;
numeric traceCoastRootIndex;
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
