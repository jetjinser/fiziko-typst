#!/usr/bin/env python3
"""Compare the packet replay with the M11 coast endpoint sweep.

Usage: compare_m11_endpoint_intersection.py MPOST_PROBE_LOG

The fixed controls are the values in m11_coast_endpoint_intersection.mp.
"""

import argparse
from pathlib import Path

from replay_s104_thin_intersections import fixed_intersection_times


def fixed(whole: int, high: int, low: int) -> int:
    return whole * 65536 + high * 256 + low


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log")
    args = parser.parse_args()

    source = {}
    for line in Path(args.log).read_text().splitlines():
        fields = line.split()
        if fields and fields[0] == "SWEEP":
            source[int(fields[1])] = float(fields[2])

    q = [
        (fixed(238, 78, 10), fixed(0, 41, 114)),
        (fixed(242, 7, 112), fixed(0, 41, 23)),
        (fixed(245, 192, 214), fixed(0, 40, 188)),
        (fixed(249, 122, 60), fixed(0, 40, 97)),
    ]
    ray_x = (
        fixed(203, 100, 9), fixed(218, 192, 197),
        fixed(234, 29, 128), fixed(249, 122, 60),
    )
    base_level = fixed(0, 40, 97)
    matches = 0
    for offset in range(-8, 9):
        level = base_level + offset
        ray = [(x, level) for x in ray_x]
        result = fixed_intersection_times(ray, [q])[1]
        expected = source[offset]
        same = ((result < 0 and expected < 0)
                or abs(result - expected) <= 1 / 65536)
        matches += same
        print(f"{offset:+3}: source={expected: .8f} "
              f"replay={result: .8f} {'match' if same else 'DIFF'}")
    print(f"sweep matches: {matches}/{len(source)}")
    if matches != 17 or len(source) != 17:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
