#!/usr/bin/env python3
"""Pair S104 source and Typst hatch rows and compare per-row RNG calls.

Usage: compare_s104_row_calls.py META_POST_LOG TYPST_ROW_TRACE.json
"""

import json
import sys
from pathlib import Path


TARGET_WIDTH_BP = 150.71053
WIDTH_TOLERANCE_BP = 0.01
BP_TO_MM = 25.4 / 72


def source_rows(path: Path):
    rows = []
    current = None
    for line in path.read_text().splitlines():
        fields = line.split()
        if fields[:1] == ["FSROW"] and len(fields) == 8:
            if current is not None:
                raise ValueError("FSROW appeared before the previous FSEND")
            current = {
                "row": float(fields[1]),
                "initial_length": float(fields[2]),
                "total_width": float(fields[3]),
                "calls": None,
                "length": 0.0,
                "requested_subdivisions": 0,
                "path_segments": 0,
            }
        elif current is not None and fields[:1] == ["FSSUB"] and len(fields) == 4:
            current.update(
                length=float(fields[1]),
                path_segments=int(float(fields[2])),
                requested_subdivisions=int(float(fields[3])),
            )
        elif current is not None and fields[:1] == ["FSEND"] and len(fields) == 3:
            current["calls"] = int(float(fields[2]))
            if abs(current["total_width"] - TARGET_WIDTH_BP) <= WIDTH_TOLERANCE_BP:
                rows.append(current)
            current = None
    # MetaPost transcript truncation can leave unrelated trailing FSROW records
    # without an FSEND. The target fixture's completed row count is checked
    # against the Typst trace below.
    # The two zero-length boundary rows do not produce a hatch path.
    return [row for row in rows if row["length"] > 0]


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source = source_rows(Path(sys.argv[1]))
    typst_doc = json.loads(Path(sys.argv[2]).read_text())
    typst = typst_doc["rows"]
    if len(source) != len(typst):
        raise ValueError(f"row count differs: source {len(source)}, Typst {len(typst)}")

    paired = []
    for index, (src, out) in enumerate(zip(source, typst), 1):
        typst_calls = round(out["rng-used"]) + 1  # one subdivision draw per row
        length_error = src["length"] * BP_TO_MM - out["length"]
        paired.append((
            index,
            src,
            out,
            typst_calls,
            length_error,
        ))

    exact = sum(src["calls"] == calls for _, src, _, calls, _ in paired)
    l1 = sum(abs(src["calls"] - calls) for _, src, _, calls, _ in paired)
    print(
        f"paired rows: {len(paired)}; exact call rows: {exact}; "
        f"call-count L1: {l1}; source/Typst total calls: "
        f"{sum(src['calls'] for src in source)}/"
        f"{sum(calls for _, _, _, calls, _ in paired)}"
    )
    mismatches = [item for item in paired if item[1]["calls"] != item[3]]
    for index, src, out, calls, length_error in mismatches[:12]:
        print(
            f"row {index}: source y={src['row']:.5f}, Typst row={out['row']}; "
            f"length delta={length_error:+.6f} mm; calls "
            f"{src['calls']}/{calls}; subdivisions "
            f"{src['requested_subdivisions']}/{out['requested-subdivisions']} "
            f"(path segments {src['path_segments']}/{out['subdivisions']}); "
            f"Typst outer/thin/dashes "
            f"{out['outer']}/{out['thin']}/{int(out['dash-calls'])}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
