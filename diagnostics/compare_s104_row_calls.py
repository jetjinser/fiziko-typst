#!/usr/bin/env python3
"""Pair S104 source and Typst hatch rows and compare per-row RNG calls.

Usage: compare_s104_row_calls.py META_POST_LOG TYPST_ROW_TRACE.json
"""

import argparse
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("typst_trace", type=Path)
    candidate = parser.add_mutually_exclusive_group()
    candidate.add_argument(
        "--generated-q",
        action="store_true",
        help="use width-q-calls from the trace instead of baseline rng-used",
    )
    candidate.add_argument(
        "--fixed-width-q",
        action="store_true",
        help="use fixed-width-q-calls from the trace",
    )
    args = parser.parse_args()
    source = source_rows(args.source_log)
    typst_doc = json.loads(args.typst_trace.read_text())
    typst = typst_doc["rows"]
    if len(source) != len(typst):
        raise ValueError(f"row count differs: source {len(source)}, Typst {len(typst)}")

    paired = []
    for index, (src, out) in enumerate(zip(source, typst), 1):
        call_field = (
            "fixed-width-q-calls" if args.fixed_width_q
            else "width-q-calls" if args.generated_q
            else "rng-used"
        )
        if out[call_field] is None:
            raise ValueError(f"Typst row {out['row']} has no {call_field} value")
        typst_calls = round(out[call_field]) + 1  # one subdivision draw per row
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
    label = (
        "fixed-width-q " if args.fixed_width_q
        else "generated-q " if args.generated_q
        else "baseline "
    )
    print(
        f"{label}paired rows: {len(paired)}; exact call rows: {exact}; "
        f"call-count L1: {l1}; source/Typst total calls: "
        f"{sum(src['calls'] for src in source)}/"
        f"{sum(calls for _, _, _, calls, _ in paired)}"
    )
    mismatches = [item for item in paired if item[1]["calls"] != item[3]]
    for index, src, out, calls, length_error in mismatches[:12]:
        if args.generated_q or args.fixed_width_q:
            prefix = "fixed-width-q" if args.fixed_width_q else "width-q"
            nodes = out[f"{prefix}-nodes"]
            outer = sum(node["stage"] == "outer" for node in nodes)
            thin = sum(node["stage"] == "thin" for node in nodes)
            dashes = int(out[f"{prefix}-dashes"])
        else:
            outer, thin, dashes = out["outer"], out["thin"], int(out["dash-calls"])
        print(
            f"row {index}: source y={src['row']:.5f}, Typst row={out['row']}; "
            f"length delta={length_error:+.6f} mm; calls "
            f"{src['calls']}/{calls}; subdivisions "
            f"{src['requested_subdivisions']}/{out['requested-subdivisions']} "
            f"(path segments {src['path_segments']}/{out['subdivisions']}); "
            f"Typst outer/thin/dashes {outer}/{thin}/{dashes}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
