#!/usr/bin/env python3
"""Compare source and Typst M9 field samples on the same lattice points.

Usage: compare_m9_field_samples.py MPOST_LOG TYPST_JSON
"""

import json
import sys
from pathlib import Path

CONTOUR_SCALE = 24


def decode_16_16(high: str, low: str) -> float:
    return int(high) / 256 + int(low) / 65536


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source_samples = {}
    for line in Path(sys.argv[1]).read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        if fields[0] == "CLVFIX" and len(source_samples) < 72:
            source_samples[(int(fields[1]), int(fields[2]))] = decode_16_16(
                fields[3], fields[4]
            )

    typst = json.loads(Path(sys.argv[2]).read_text())
    typst_samples = {
        (sample["i"], sample["j"]): sample["wfield"] / CONTOUR_SCALE
        for row in typst["raw-grid-samples"]
        for sample in row
    }
    if len(source_samples) != 72 or len(typst_samples) != 72:
        raise SystemExit(
            "expected 72 source/Typst samples; "
            f"got {len(source_samples)}/{len(typst_samples)}"
        )

    errors = []
    for (i, j), source_value in source_samples.items():
        if (i, j) not in typst_samples:
            raise SystemExit(f"missing Typst sample {(i, j)}")
        # CLVFIX is emitted after adding the per-column random offset, just
        # like the Typst field. Divide Typst's 24x contour scale, then compare
        # the two values directly; subtracting CLCOL from only one side adds
        # the whole column offset to the measured error.
        errors.append((i, j, typst_samples[(i, j)] - source_value))

    absolute = [abs(error) for _, _, error in errors]
    exact = sum(error == 0 for _, _, error in errors)
    print(
        f"samples: {len(errors)}; exact: {exact}; "
        f"mean absolute field error: {sum(absolute) / len(absolute):.9g}; "
        f"max absolute field error: {max(absolute):.9g}"
    )
    for i in sorted({sample_i for sample_i, _, _ in errors}):
        column_errors = [error for x, _, error in errors if x == i]
        mean = sum(column_errors) / len(column_errors)
        print(f"column {i:2d}: mean signed field error {mean:+.9g}")


if __name__ == "__main__":
    main()
