#!/usr/bin/env python3
"""Compare exact M9 source cLine corner values with the Typst field trace."""

import json
import sys
from pathlib import Path


def source_data(path: Path):
    level = None
    cells = {}
    for line in path.read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        if fields[0] == "CLLEVELFIX" and len(fields) == 3:
            level = int(fields[1]) * 256 + int(fields[2])
        elif fields[0] == "CLSTEPFIX" and len(fields) == 13:
            i, j = map(int, fields[1:3])
            values = tuple(
                int(fields[k]) * 256 + int(fields[k + 1])
                for k in range(3, 11, 2)
            )
            cells[(i, j)] = values
    if level is None or not cells:
        raise SystemExit("source trace is missing CLLEVELFIX or CLSTEPFIX")
    return level, cells


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: compare_m9_cell_corners.py SOURCE_LOG TYPST_JSON")
    source_level, source_cells = source_data(Path(sys.argv[1]))
    typst = json.loads(Path(sys.argv[2]).read_text())
    typst_cells = {
        (32 - int(item["cell"][1]), int(item["cell"][0])): item
        for item in typst.get("cell-corners-fixed", ())
    }
    keys = sorted(source_cells.keys() & typst_cells.keys())
    if not keys:
        raise SystemExit("source and Typst traces have no matching cLine cells")
    field_errors = []
    contour_errors = []
    for key in keys:
        source_corners = source_cells[key]
        item = typst_cells[key]
        typst_fields = tuple(item["fields"])
        typst_corners = tuple(item["corners"])
        source_fields = tuple(value - source_level for value in source_corners)
        field_errors.extend(abs(a - b) for a, b in zip(source_fields, typst_fields))
        contour_errors.extend(abs(a - b) for a, b in zip(source_corners, typst_corners))
        if any(a != b for a, b in zip(source_fields, typst_fields)):
            print(f"cell {key}: source field {source_fields}; Typst {typst_fields}; "
                  f"source c+level {source_corners}; Typst c+level {typst_corners}")
    print(f"paired cells: {len(keys)}/{len(source_cells)}")
    print(f"field corners exact: {sum(e == 0 for e in field_errors)}/{len(field_errors)}; "
          f"mean/max abs error {sum(field_errors) / len(field_errors):.3f}/"
          f"{max(field_errors)} fixed units")
    print(f"cLine corners exact: {sum(e == 0 for e in contour_errors)}/{len(contour_errors)}; "
          f"mean/max abs error {sum(contour_errors) / len(contour_errors):.3f}/"
          f"{max(contour_errors)} fixed units")


if __name__ == "__main__":
    main()
