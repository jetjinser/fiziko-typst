#!/usr/bin/env python3
"""Export M4PATH records from an instrumented MetaPost log as Typst data."""

import re
import sys
from pathlib import Path


RECORD = re.compile(r"M4PATH ([0-9.]+) ([0-9.]+) ([0-9.]+)")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_m4_tube_path.py TRACE_LOG OUTPUT_TYP")
    source = Path(sys.argv[1]).read_text()
    times = [float(t) for t, _, _ in RECORD.findall(source)]
    points = [(float(x), float(y)) for _, x, y in RECORD.findall(source)]
    if len(points) < 2:
        raise ValueError(f"expected at least two M4 path samples, got {len(points)}")
    step_denominator = round(1 / (times[1] - times[0]))
    if any(abs(t - i / step_denominator) > 1e-8
           for i, t in enumerate(times)):
        raise ValueError("source samples are not on a uniform path-time grid")
    if abs(times[-1] - round(times[-1])) > 1e-8:
        raise ValueError("source path endpoint is not on the requested sample grid")
    values = [f"({x:.5f}, {y:.5f})" for x, y in points]
    output = (
        f"// M4 tube centerline sampled from the pinned MetaPost driver at {1/step_denominator:g} path-time intervals.\n"
        f"#let upstream-m4-tube-path-step = {step_denominator}\n"
        "#let upstream-m4-tube-path = (\n  "
        + ",\n  ".join(values)
        + "\n)\n"
    )
    Path(sys.argv[2]).write_text(output)


if __name__ == "__main__":
    main()
