#!/usr/bin/env python3
"""Export M11PATH records from an instrumented MetaPost log as Typst data."""

import re
import sys
from pathlib import Path


RECORD = re.compile(r"M11PATH ([AB]) ([0-9.]+) ([0-9.]+) ([0-9.]+)")
FIXED_RECORD = re.compile(
    r"M11PATHFIX ([AB]) ([0-9.]+) (-?[0-9]+) ([0-9]+) ([0-9]+) "
    r"(-?[0-9]+) ([0-9]+) ([0-9]+)"
)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_m11_knot_paths.py TRACE_LOG OUTPUT_TYP")
    source = Path(sys.argv[1]).read_text()
    paths: dict[str, list[tuple[float, float]]] = {"A": [], "B": []}
    times: dict[str, list[float]] = {"A": [], "B": []}
    fixed_paths: dict[str, list[tuple[float, float]]] = {"A": [], "B": []}
    fixed_times: dict[str, list[float]] = {"A": [], "B": []}
    for strand, time, x, y in RECORD.findall(source):
        times[strand].append(float(time))
        paths[strand].append((float(x), float(y)))
    for strand, time, xi, xh, xl, yi, yh, yl in FIXED_RECORD.findall(source):
        fixed_times[strand].append(float(time))
        x = int(xi) + int(xh) / 256 + int(xl) / 65536
        y = int(yi) + int(yh) / 256 + int(yl) / 65536
        fixed_paths[strand].append((x * 25.4 / 72, y * 25.4 / 72))
    if len(paths["A"]) < 2 or len(paths["A"]) != len(paths["B"]):
        raise ValueError(f"expected equal nonempty strand samples, got {len(paths['A'])} and {len(paths['B'])}")
    if times["A"] != times["B"]:
        raise ValueError("source strand samples do not share identical path times")
    step_denominator = round(1 / (times["A"][1] - times["A"][0]))
    if any(abs(t - i / step_denominator) > 1e-8
           for i, t in enumerate(times["A"])):
        raise ValueError("source samples are not on a uniform path-time grid")

    if fixed_paths["A"] or fixed_paths["B"]:
        if (len(fixed_paths["A"]) != len(times["A"])
                or len(fixed_paths["B"]) != len(times["B"])
                or fixed_times["A"] != times["A"]
                or fixed_times["B"] != times["B"]):
            raise ValueError("fixed-point and decimal path records do not pair")
        paths = fixed_paths

    def array(points: list[tuple[float, float]]) -> str:
        values = [f"({x:.9f}, {y:.9f})" for x, y in points]
        return "(\n  " + ",\n  ".join(values) + "\n)"

    precision = " with 16.16 bp coordinates" if fixed_paths["A"] else ""
    output = (
        f"// M11 knot paths sampled from the pinned MetaPost 2.11 source at {times['A'][1] - times['A'][0]:g} path-time intervals{precision}.\n"
        "#let upstream-m11-knot-paths = (\n"
        f"  path-step: {step_denominator},\n"
        f"  wa: {array(paths['A'])},\n"
        f"  wb: {array(paths['B'])},\n"
        ")\n"
    )
    Path(sys.argv[2]).write_text(output)


if __name__ == "__main__":
    main()
