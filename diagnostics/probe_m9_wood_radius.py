#!/usr/bin/env python3
"""Compare a 16.16 square-root radius with traced MetaPost wood radii."""

import argparse
import math
from pathlib import Path


SCALE = 65536


def round_fixed(value: float) -> int:
    magnitude = math.floor(abs(value) + 0.5)
    return -magnitude if value < 0 else magnitude


def decode(whole: str, fraction: str) -> int:
    return int(whole) * 256 + int(fraction)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    args = parser.parse_args()

    vectors = {}
    radii = []
    for line in args.source_log.read_text().splitlines():
        fields = line.split()
        if fields[:1] == ["CLWPAIRFIX"] and len(fields) == 10:
            index = int(fields[1])
            scaled_x = decode(fields[6], fields[7])
            scaled_y = decode(fields[8], fields[9])
            vectors[index] = (scaled_x, scaled_y)
        elif fields[:1] == ["CLWRFIX"] and len(fields) == 5:
            radii.append(decode(fields[1], fields[2]))

    if len(vectors) != len(radii) or not vectors:
        raise SystemExit(
            f"incomplete source radius trace: {len(vectors)} vectors, {len(radii)} radii")

    errors = []
    for index, source_radius in enumerate(radii):
        x, y = vectors[index]
        x2 = round_fixed(x * x / SCALE)
        y2 = round_fixed(y * y / SCALE)
        candidate = round_fixed(math.sqrt((x2 + y2) / SCALE) * SCALE)
        error = candidate - source_radius
        errors.append(error)
        print(f"knot {index}: source={source_radius}; sqrt={candidate}; delta={error}")
    print(f"max absolute error: {max(map(abs, errors))} fixed units")
    print(f"exact radius matches: {sum(error == 0 for error in errors)}/{len(errors)}")


if __name__ == "__main__":
    main()
