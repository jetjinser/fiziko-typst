#!/usr/bin/env python3
"""Summarize the instrumented source stipple calls in an S101 MetaPost log.

Usage: summarize_stipple_trace.py MPOST_LOG
"""

import math
import sys
from collections import Counter
from pathlib import Path


def parse(path):
    sections = {}
    current_object = None
    record = None
    for line in Path(path).read_text().splitlines():
        if line.startswith("OBJECT "):
            current_object = line.removeprefix("OBJECT ")
            sections.setdefault(current_object, [])
            record = None
        elif line == "S101 TRY":
            if current_object is None:
                raise ValueError("found a trace record before an OBJECT marker")
            record = {"patterns": []}
            sections[current_object].append(record)
        elif record is not None:
            if line.startswith("S101 WIDTH "):
                record["width"] = float(line.split()[2])
            elif line.startswith("S101 LENGTH "):
                record["length"] = float(line.split()[2])
            elif line == "S101 PATTERN":
                record["patterns"].append({})
            elif line.startswith("S101 PARAM "):
                n, rn, size, length = map(float, line.split()[2:6])
                record["patterns"][-1].update(
                    n=n, rn=int(rn), size=size, length=length
                )
            elif line.startswith("S101 OFF1 "):
                record["patterns"][-1]["off1"] = float(line.split()[2])
            elif line.startswith("S101 OFF2 "):
                record["patterns"][-1]["off2"] = float(line.split()[2])
            elif line.startswith("S101 SINGLE "):
                record["patterns"][-1]["single"] = float(line.split()[2])
            elif line.startswith("S101 CHANCE "):
                record["patterns"][-1]["chance"] = float(line.split()[2])
            elif line == "S101 EMPTY":
                record["patterns"][-1]["empty"] = True
    return sections


def count_dots(pattern):
    if pattern["rn"] == 0:
        return int("single" in pattern)

    period = pattern["length"] / pattern["rn"]
    offsets = [pattern["off1"]]
    if pattern["rn"] >= 3:
        offsets.append(period + pattern["off2"])
        period *= 2
    return sum(
        max(0, math.ceil((pattern["length"] - offset) / period))
        for offset in offsets
    )


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)

    sections = parse(sys.argv[1])
    for name in ("BRUSH", "SPHERE", "TUBE"):
        records = sections.get(name, [])
        leaves = [record for record in records if "width" in record]
        patterns = [pattern for record in records for pattern in record["patterns"]]
        if not leaves or not patterns:
            raise SystemExit(f"incomplete {name} trace")

        sizes = [pattern["size"] for pattern in patterns]
        lengths = [record["length"] * (25.4 / 72) for record in leaves]
        rn_counts = Counter(pattern["rn"] for pattern in patterns)
        dots = sum(count_dots(pattern) for pattern in patterns)
        print(
            f"{name.lower()}: drawable leaves={len(leaves)}, "
            f"pattern calls={len(patterns)}, reconstructed dots={dots}"
        )
        print(
            f"  dot diameter in MetaPost bp: {min(sizes):.5f}–{max(sizes):.5f}, "
            f"mean={sum(sizes) / len(sizes):.5f}; "
            f"zero-integer-count patterns={rn_counts[0]}"
        )
        print(
            f"  leaf length in mm: min={min(lengths):.5f}, "
            f"median={sorted(lengths)[len(lengths) // 2]:.5f}, "
            f"mean={sum(lengths) / len(lengths):.5f}, max={max(lengths):.5f}"
        )


if __name__ == "__main__":
    main()
