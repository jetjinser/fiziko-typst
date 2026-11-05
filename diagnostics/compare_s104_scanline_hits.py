#!/usr/bin/env python3
"""Compare source and Typst S104 forward/reverse scanline clipping hits."""

import argparse
import json
from pathlib import Path

from compare_s104_row_calls import source_rows


SCALE = 65536


def fixed(whole, high, low):
    return int(whole) * SCALE + int(high) * 256 + int(low)


def source_hits(path):
    rows = {}
    for line in path.read_text().splitlines():
        fields = line.split()
        if not fields or fields[0] not in ("S104-CLIP-T1", "S104-CLIP-T2"):
            continue
        if len(fields) != 8:
            raise ValueError(f"malformed {fields[0]} record: {line}")
        _, row, *parts = fields
        rows.setdefault(float(row), {})[fields[0]] = (
            fixed(*parts[:3]), fixed(*parts[3:]))
    return rows


def typst_rows(path):
    data = json.loads(path.read_text())
    if isinstance(data, list) and len(data) == 1 and isinstance(data[0], dict):
        data = data[0]
    rows = data["rows"] if isinstance(data, dict) else data
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("typst_trace", type=Path)
    args = parser.parse_args()

    source = source_rows(args.source_log)
    candidate = typst_rows(args.typst_trace)
    if len(source) != len(candidate):
        raise ValueError(f"row counts differ: source {len(source)}, Typst {len(candidate)}")
    expected = source_hits(args.source_log)
    matched = 0
    mismatches = []
    missing = []
    for src, typ in zip(source, candidate):
        row = src["row"]
        records = expected.get(row)
        if records is None or set(records) != {"S104-CLIP-T1", "S104-CLIP-T2"}:
            missing.append(row)
            continue
        actual = typ.get("intersection-hits", ())
        want = (records["S104-CLIP-T1"], records["S104-CLIP-T2"])
        got = tuple(tuple(round(float(value) * SCALE) for value in pair)
                    for pair in actual)
        if got == want:
            matched += 1
        else:
            mismatches.append((row, typ.get("row"), got, want))

    print(f"exact source/Typst forward-reverse hit pairs: {matched}/{len(source)}")
    if missing:
        print(f"rows without complete source clip records: {len(missing)}")
    for row, typ_row, got, want in mismatches[:12]:
        print(f"source row={row:g} Typst row={typ_row}: Typst={got}; source={want}")
    if missing or mismatches:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
