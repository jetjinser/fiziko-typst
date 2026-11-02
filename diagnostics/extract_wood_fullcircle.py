#!/usr/bin/env python3
"""Extract the pinned MetaPost fullcircle samples used by the wood-knot brush."""

from __future__ import annotations

import re
import sys
from pathlib import Path


RECORD = re.compile(r"WFC ([0-9.]+) (-?[0-9.]+) (-?[0-9.]+) (-?[0-9.]+)")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_wood_fullcircle.py TRACE_LOG OUTPUT_TYP")

    source = Path(sys.argv[1]).read_text()
    records = [tuple(map(float, match)) for match in RECORD.findall(source)]
    if len(records) < 9 or records[0][0] != 0 or records[-1][0] != 8:
        raise SystemExit(f"expected fullcircle samples from path time 0 to 8, got {len(records)}")
    steps = {round(b[0] - a[0], 8) for a, b in zip(records, records[1:])}
    if len(steps) != 1 or len(records) != 8 / steps.pop() + 1:
        raise SystemExit("fullcircle trace has inconsistent path-time spacing")

    output = [
        "// Pinned MetaPost fullcircle samples for the wood-knot ring probe.",
        f"#let upstream-wood-fullcircle-step = {records[1][0] - records[0][0]:g}",
        "#let upstream-wood-fullcircle = (",
    ]
    output.extend(
        f"  ({x:.8f}, {y:.8f}, {width:.8f}),"
        for _, x, y, width in records
    )
    output.append(")")
    Path(sys.argv[2]).write_text("\n".join(output) + "\n")


if __name__ == "__main__":
    main()
