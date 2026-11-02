#!/usr/bin/env python3
"""Export successful M11 shadow cuts as a Typst replay module."""

import sys
from collections import defaultdict
from pathlib import Path


def export(source_path: str, output_path: str) -> None:
    cuts = defaultdict(list)
    for line in Path(source_path).read_text().splitlines():
        fields = line.split()
        if fields and fields[0] == "M11CUT":
            key = (int(fields[1]), int(fields[2]))
            cuts[key].append((float(fields[4]), float(fields[6])))

    cases = []
    for (call, lane), records in sorted(cuts.items()):
        if not records:
            continue
        initial = int(round(records[0][1]))
        splices = []
        for current, following in zip(records, records[1:]):
            cut_time, path_length = current
            if 0.1 < cut_time < path_length - 0.1:
                splices.append((cut_time, int(round(following[1]))))
        cases.append((call, lane, initial,
                      int(round(records[-1][1])), splices))

    lines = ["#let m11-shadow-cases = ("]
    for call, lane, initial, terminal, splices in cases:
        splice_values = ", ".join(
            f"(time: {time:.5f}, length: {length})"
            for time, length in splices
        )
        splice_tuple = f"({splice_values})" if splices else "()"
        lines.append(
            f"  (call: {call}, lane: {lane}, initial: {initial}, "
            f"terminal: {terminal}, splices: {splice_tuple}),"
        )
    lines.append(")")
    Path(output_path).write_text("\n".join(lines) + "\n")
    print(f"exported {len(cases)} lanes and "
          f"{sum(len(case[4]) for case in cases)} successful cuts")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: extract_m11_shadow_splice_cases.py TRACE_LOG OUTPUT_TYP"
        )
    export(sys.argv[1], sys.argv[2])
