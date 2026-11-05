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
SCALE_RECORD = re.compile(r"M11PATHSCALE ([0-9]+) ([0-9]+) ([0-9]+)")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_m11_knot_paths.py TRACE_LOG OUTPUT_TYP")
    source = Path(sys.argv[1]).read_text()
    paths: dict[str, list[tuple[float, float]]] = {"A": [], "B": []}
    times: dict[str, list[float]] = {"A": [], "B": []}
    fixed_records: dict[str, list[tuple[int, int, int, int, int, int]]] = {
        "A": [], "B": []
    }
    fixed_times: dict[str, list[float]] = {"A": [], "B": []}
    scale_records = SCALE_RECORD.findall(source)
    if len(scale_records) > 1:
        raise ValueError("expected at most one fixed-point mm scale record")
    for strand, time, x, y in RECORD.findall(source):
        times[strand].append(float(time))
        paths[strand].append((float(x), float(y)))
    for strand, time, xi, xh, xl, yi, yh, yl in FIXED_RECORD.findall(source):
        fixed_times[strand].append(float(time))
        fixed_records[strand].append(
            (int(xi), int(xh), int(xl), int(yi), int(yh), int(yl))
        )
    if len(paths["A"]) < 2 or len(paths["A"]) != len(paths["B"]):
        raise ValueError(f"expected equal nonempty strand samples, got {len(paths['A'])} and {len(paths['B'])}")
    if times["A"] != times["B"]:
        raise ValueError("source strand samples do not share identical path times")
    step_denominator = round(1 / (times["A"][1] - times["A"][0]))
    if any(abs(t - i / step_denominator) > 1e-8
           for i, t in enumerate(times["A"])):
        raise ValueError("source samples are not on a uniform path-time grid")

    if fixed_records["A"] or fixed_records["B"]:
        if len(scale_records) != 1:
            raise ValueError("fixed-point path records require M11PATHSCALE")
        if (len(fixed_records["A"]) != len(times["A"])
                or len(fixed_records["B"]) != len(times["B"])
                or fixed_times["A"] != times["A"]
                or fixed_times["B"] != times["B"]):
            raise ValueError("fixed-point and decimal path records do not pair")
        scale_int, scale_high, scale_low = map(int, scale_records[0])
        mm_scale = scale_int + scale_high / 256 + scale_low / 65536
        if mm_scale <= 0:
            raise ValueError("fixed-point mm scale must be positive")
        fixed_paths = {
            strand: [
                ((xi * 65536 + xh * 256 + xl) / (mm_scale * 65536),
                 (yi * 65536 + yh * 256 + yl) / (mm_scale * 65536))
                for xi, xh, xl, yi, yh, yl in fixed_records[strand]
            ]
            for strand in ("A", "B")
        }
        for strand in ("A", "B"):
            errors = [max(abs(a - b) for a, b in zip(fixed, decimal))
                      for fixed, decimal in zip(fixed_paths[strand], paths[strand])]
            if max(errors, default=0) > 0.00002:
                raise ValueError(
                    f"fixed-point path differs from decimal sanity trace for {strand}: "
                    f"max {max(errors):.9g} mm")
        paths = fixed_paths

    def array(points: list[tuple[float, float]]) -> str:
        values = [f"({x:.9f}, {y:.9f})" for x, y in points]
        return "(\n  " + ",\n  ".join(values) + "\n)"

    precision = " with 16.16 bp coordinates" if fixed_records["A"] else ""
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
