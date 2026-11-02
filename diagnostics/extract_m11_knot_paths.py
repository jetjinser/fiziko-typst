#!/usr/bin/env python3
"""Export M11PATH records from an instrumented MetaPost log as Typst data."""

import re
import sys
from pathlib import Path


RECORD = re.compile(r"M11PATH ([AB]) ([0-9.]+) ([0-9.]+) ([0-9.]+)")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_m11_knot_paths.py TRACE_LOG OUTPUT_TYP")
    source = Path(sys.argv[1]).read_text()
    paths: dict[str, list[tuple[float, float]]] = {"A": [], "B": []}
    for strand, _time, x, y in RECORD.findall(source):
        paths[strand].append((float(x), float(y)))
    if len(paths["A"]) != 97 or len(paths["B"]) != 97:
        raise ValueError(
            f"expected 97 samples per strand, got {len(paths['A'])} and {len(paths['B'])}"
        )

    def array(points: list[tuple[float, float]]) -> str:
        values = [f"({x:.5f}, {y:.5f})" for x, y in points]
        return "(\n  " + ",\n  ".join(values) + "\n)"

    output = (
        "// M11 knot paths sampled from the pinned MetaPost 2.11 source at 1/4 path-time intervals.\n"
        "#let upstream-m11-knot-paths = (\n"
        f"  wa: {array(paths['A'])},\n"
        f"  wb: {array(paths['B'])},\n"
        ")\n"
    )
    Path(sys.argv[2]).write_text(output)


if __name__ == "__main__":
    main()
