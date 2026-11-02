#!/usr/bin/env python3
"""Export M7PATH records from an instrumented MetaPost log as Typst data."""

import re
import sys
from pathlib import Path


RECORD = re.compile(r"M7PATH ([0-9.]+) ([0-9.]+) ([0-9.]+)")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_m7_tube_path.py TRACE_LOG OUTPUT_TYP")
    records = RECORD.findall(Path(sys.argv[1]).read_text())
    times = [float(t) for t, _, _ in records]
    points = [(float(x), float(y)) for _, x, y in records]
    if len(points) < 2:
        raise ValueError(f"expected at least two M7 path samples, got {len(points)}")
    step_denominator = round(1 / (times[1] - times[0]))
    if any(abs(t - i / step_denominator) > 1e-8
           for i, t in enumerate(times)):
        raise ValueError("source samples are not on a uniform path-time grid")
    values = [f"({x:.5f}, {y:.5f})" for x, y in points]
    output = (
        f"// M7 tube centerline sampled from the pinned MetaPost driver at {1/step_denominator:g} path-time intervals.\n"
        f"#let upstream-m7-tube-path-step = {step_denominator}\n"
        "#let upstream-m7-tube-path = (\n  "
        + ",\n  ".join(values)
        + "\n)\n"
    )
    Path(sys.argv[2]).write_text(output)


if __name__ == "__main__":
    main()
