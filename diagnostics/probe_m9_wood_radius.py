#!/usr/bin/env python3
"""Compare a 16.16 square-root radius with traced MetaPost wood radii."""

import argparse
import math
from pathlib import Path


SCALE = 65536
FRACTION_ONE = 4096 * SCALE


def round_fixed(value: float) -> int:
    magnitude = math.floor(abs(value) + 0.5)
    return -magnitude if value < 0 else magnitude


def decode(whole: str, fraction: str) -> int:
    return int(whole) * 256 + int(fraction)


def round_ratio(numerator: int, denominator: int) -> int:
    sign = -1 if (numerator < 0) != (denominator < 0) else 1
    return sign * ((abs(numerator) + abs(denominator) // 2) // abs(denominator))


def pyth_add(x: int, y: int) -> int:
    """Replay MetaPost's fixed-point pyth_add for 16.16 coordinates."""
    a, b = abs(x), abs(y)
    if a < b:
        a, b = b, a
    if b == 0:
        return a
    big = a >= 2 * FRACTION_ONE
    if big:
        a //= 4
        b //= 4
    while True:
        ratio = round_ratio(b * FRACTION_ONE, a)
        ratio = round_ratio(ratio * ratio, FRACTION_ONE)
        if ratio == 0:
            break
        ratio = round_ratio(ratio * FRACTION_ONE,
                            4 * FRACTION_ONE + ratio)
        a += round_ratio(2 * a * ratio, FRACTION_ONE)
        b = round_ratio(b * ratio, FRACTION_ONE)
    return a * 4 if big else a


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
    pyth_errors = []
    for index, source_radius in enumerate(radii):
        x, y = vectors[index]
        x2 = round_fixed(x * x / SCALE)
        y2 = round_fixed(y * y / SCALE)
        candidate = round_fixed(math.sqrt((x2 + y2) / SCALE) * SCALE)
        error = candidate - source_radius
        errors.append(error)
        pyth = pyth_add(x, y)
        pyth_error = pyth - source_radius
        pyth_errors.append(pyth_error)
        print(f"knot {index}: source={source_radius}; sqrt={candidate} "
              f"(delta {error}); pyth_add={pyth} (delta {pyth_error})")
    print(f"max absolute error: {max(map(abs, errors))} fixed units")
    print(f"exact radius matches: {sum(error == 0 for error in errors)}/{len(errors)}")
    print(f"pyth_add max absolute error: {max(map(abs, pyth_errors))} fixed units")
    print(f"pyth_add exact radius matches: "
          f"{sum(error == 0 for error in pyth_errors)}/{len(pyth_errors)}")


if __name__ == "__main__":
    main()
