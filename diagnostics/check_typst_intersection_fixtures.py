#!/usr/bin/env python3
"""Verify the Typst packet-search port against recorded S104 and M11 source fixtures.

Run inside the repository devshell:
  python3 diagnostics/check_typst_intersection_fixtures.py M11_PROBE_LOG
"""

import json
import subprocess
import sys
from pathlib import Path


UNIT = 1 / 65536


def close_pair(actual, expected, tolerance=UNIT):
    return all(abs(a - b) <= tolerance for a, b in zip(actual, expected))


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    result = subprocess.run(
        [
            "typst", "eval",
            "query(<metapost-intersection-sweep>).first().value",
            "--in", "diagnostics/metapost_intersection_sweep.typ",
            "--root", ".",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    data = json.loads(result.stdout)

    expected_s104 = (
        ((0.0, 1.5001678466796875),
         (0.94110107421875, 0.9981689453125)),
        ((0.9416046142578125, 1.0),
         (0.9416046142578125, 2.0)),
    )
    for ray, expected in zip(("ray1", "ray2"), expected_s104):
        actual = data["s104"][ray]["raw"]
        if not all(close_pair(got, want) for got, want in zip(actual, expected)):
            raise SystemExit(f"S104 {ray} raw pairs differ: {actual} != {expected}")
    print("S104 node 172 raw pairs: 4/4 match within one 16.16 unit")

    source = {}
    for line in Path(sys.argv[1]).read_text().splitlines():
        fields = line.split()
        if fields and fields[0] == "SWEEP":
            source[int(fields[1])] = float(fields[2])
    actual_by_offset = {item["offset"]: item["selected"][1]
                        for item in data["m11"]}
    matches = 0
    for offset, wanted in sorted(source.items()):
        got = actual_by_offset[offset]
        same = ((got < 0 and wanted < 0)
                or abs(got - wanted) <= UNIT + 0.0000051)
        matches += same
        if not same:
            print(f"M11 offset {offset:+}: Typst={got:.8f} source={wanted:.8f}")
    print(f"M11 endpoint sweep: {matches}/{len(source)} match")
    if matches != 17 or len(actual_by_offset) != 17:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
