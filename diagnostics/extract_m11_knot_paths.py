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
    times: dict[str, list[float]] = {"A": [], "B": []}
    for strand, time, x, y in RECORD.findall(source):
        times[strand].append(float(time))
        paths[strand].append((float(x), float(y)))
    if len(paths["A"]) < 2 or len(paths["A"]) != len(paths["B"]):
        raise ValueError(f"expected equal nonempty strand samples, got {len(paths['A'])} and {len(paths['B'])}")
    if times["A"] != times["B"]:
        raise ValueError("source strand samples do not share identical path times")
    step_denominator = round(1 / (times["A"][1] - times["A"][0]))
    if any(abs(t - i / step_denominator) > 1e-8
           for i, t in enumerate(times["A"])):
        raise ValueError("source samples are not on a uniform path-time grid")

    def array(points: list[tuple[float, float]]) -> str:
        values = [f"({x:.5f}, {y:.5f})" for x, y in points]
        return "(\n  " + ",\n  ".join(values) + "\n)"

    output = (
        f"// M11 knot paths sampled from the pinned MetaPost 2.11 source at {times['A'][1] - times['A'][0]:g} path-time intervals.\n"
        "#let upstream-m11-knot-paths = (\n"
        f"  path-step: {step_denominator},\n"
        f"  wa: {array(paths['A'])},\n"
        f"  wb: {array(paths['B'])},\n"
        ")\n"
    )
    Path(sys.argv[2]).write_text(output)


if __name__ == "__main__":
    main()
