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
    subdivide_anchor = "aHatch := pathSubdivide(aHatch,3+round(uniformdeviate(2)));"
    if source.count(subdivide_anchor) != 1:
        raise ValueError(f"expected one pathSubdivide hook, found {source.count(subdivide_anchor)}")
    source = source.replace(
        subdivide_anchor,
        subdivide_anchor + "\n                message \"FSSUB \" & decimal(arclength(aHatch)) & \" \" & decimal(length(aHatch));",
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
vardef traceUniformdeviate (expr x) =
    traceRngTotal := traceRngTotal + 1;
    uniformdeviate(x)
enddef;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
