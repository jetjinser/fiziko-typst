#!/usr/bin/env python3
"""Trace cLine's first wood contour cell visits in a copy of fiziko.mp."""

import sys
from pathlib import Path


def replace_once(source: str, anchor: str, replacement: str, name: str) -> str:
    count = source.count(anchor)
    if count != 1:
        raise ValueError(f"expected one {name} hook, found {count}")
    return source.replace(anchor, replacement)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: instrument_wood_contours.py UPSTREAM_FIZIKO_MP OUTPUT_MP")
    source = Path(sys.argv[1]).read_text()
    c_line_anchor = "    sqS := max(c1, c2, c3, c4) - min(c1, c2, c3, c4);"
    c_line_trace = c_line_anchor + """
        if traceWoodCells:
            message "CLSTEP " & decimal(i) & " " & decimal(j) & " "
                & decimal(st) & " " & decimal(sqS) & " "
                & decimal(xpart(dr)) & " " & decimal(ypart(dr));
        fi;"""
    source = replace_once(source, c_line_anchor, c_line_trace, "cLine cell")
    boundary_anchor = "    else:\n        outputPath := (i, j);"
    boundary_trace = (
        '    else:\n'
        '        if traceWoodCells:\n'
        '            message "CLSTEP " & decimal(i) & " " & decimal(j) & " "\n'
        '                & decimal(st) & " 0 0 0";\n'
        '        fi;\n'
        '        outputPath := (i, j);'
    )
    source = replace_once(source, boundary_anchor, boundary_trace, "cLine boundary cell")

    call_anchor = "iL := cLine (xy)((i, j), (0, 0), 0, cs) scaled s;"
    call_trace = """traceWoodLine := traceWoodLine + 1;
                            traceWoodCells := (traceWoodLine = 1);
                            iL := cLine (xy)((i, j), (0, 0), 0, cs) scaled s;
                            if traceWoodLine = 1:
                                message "CLLEVEL " & decimal(lvl);
                                message "CLSPAN " & decimal(sqB) & " "
                                    & decimal(sqBm) & " " & decimal(length(iL));
                                for traceWoodPoint := 0 step 1 until length(iL):
                                    message "CLPATH " & decimal(traceWoodPoint) & " "
                                        & decimal(xpart(point traceWoodPoint of iL)/mm) & " "
                                        & decimal(ypart(point traceWoodPoint of iL)/mm);
                                endfor;
                            fi;
                            traceWoodCells := false;"""
    source = replace_once(source, call_anchor, call_trace, "isoLines call")

    width_anchor = "offsetPathTemplate(iL, 0)(\n"
    width_trace = """offsetPathTemplate(iL, 0)(
                            begingroup
                            if traceWoodLine = 1:
                                if (offsetPathTime < length(iL) - 1):
                                    message "CLWIDTH " & decimal(offsetPathTime) & " "
                                        & decimal(sqB) & " " & decimal(sqBm) & " "
                                        & decimal(length(iL)) & " "
                                        & decimal(v[floor(sqB + offsetPathTime)]) & " "
                                        & decimal(v[ceiling(sqB + offsetPathTime)]);
                                else:
                                    message "CLWIDTH " & decimal(offsetPathTime) & " "
                                        & decimal(sqB) & " " & decimal(sqBm) & " "
                                        & decimal(length(iL)) & " 1 1";
                                fi;
                            fi;
                            """
    source = replace_once(source, width_anchor, width_trace, "isoLines width callback")
    width_end_anchor = "\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t, 0);"
    width_end_trace = """\t\t\t\t\t\t\tendgroup
\t\t\t\t\t\t\t)
\t\t\t\t\t\t\t, 0);"""
    source = replace_once(source, width_end_anchor, width_end_trace,
                           "isoLines width callback end")

    range_anchor = "for i := -maxWithinMask/woodBlockYRdensity - 1 upto -minWithinMask/woodBlockYRdensity + 1:"
    range_trace = (
        'message "CLFIELD " & decimal(minWithinMask) & " " & decimal(maxWithinMask);\n'
        + range_anchor
    )
    source = replace_once(source, range_anchor, range_trace, "wood field range")
    field_anchor = "wood[i][j] := wField (wKnot)(i, j, (wS, lS), nwKnot) + k;"
    field_trace = field_anchor + """
                if traceWoodBlock = 1:
                    if i <= 5:
                        if (j >= 12) and (j <= 23):
                            message "CLVALUE " & decimal(i) & " " & decimal(j) & " "
                                & decimal(wood[i][j]);
                        fi;
                    fi;
                fi;"""
    source = replace_once(source, field_anchor, field_trace, "wood field sample")
    max_anchor = "if wood[i][j] > maxWithinMask:"
    max_trace = max_anchor + "\n                            message \"CLMAX \" & decimal(i) & \" \" & decimal(j) & \" \" & decimal(wood[i][j]);"
    source = replace_once(source, max_anchor, max_trace, "wood field maximum")
    block_anchor = "vardef woodBlock (expr w, l) ="
    block_trace = block_anchor + "\n    traceWoodBlock := traceWoodBlock + 1;"
    source = replace_once(source, block_anchor, block_trace, "wood block")
    source += """

boolean traceWoodCells;
numeric traceWoodLine, traceWoodPoint, traceWoodBlock;
traceWoodCells := false;
traceWoodLine := 0;
traceWoodBlock := 0;
"""
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
