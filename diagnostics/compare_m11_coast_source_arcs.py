#!/usr/bin/env python3
"""Compare source root q.x knots with arclengths of traced source path cubics.

Usage: compare_m11_coast_source_arcs.py MPOST_LOG
"""

import sys
from collections import defaultdict
from pathlib import Path

from audit_m11_q_arclength import metapost_arc_length_fixed


def fixed(value: str) -> int:
    whole, high, low = map(int, value.split(":"))
    return whole * 65536 + high * 256 + low


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    curves = defaultdict(dict)
    knots = defaultdict(list)
    source_arcs = defaultdict(dict)
    source_segment_arcs = defaultdict(dict)
    for line in Path(sys.argv[1]).read_text().splitlines():
        fields = line.split()
        if fields[:1] == ["M11-PATHP-FIX"]:
            mass, segment, control = map(int, fields[1:4])
            curves[mass].setdefault(segment, {})[control] = (
                fixed(fields[4]), fixed(fields[5]))
        elif fields[:1] == ["M11-ROOTQ"]:
            mass = int(fields[1])
            knots[mass].append((int(fields[2]), fixed(fields[3])))
        elif fields[:1] == ["M11-PATHARC"]:
            mass, boundary = map(int, fields[1:3])
            source_arcs[mass][boundary] = fixed(fields[3])
        elif fields[:1] == ["M11-PATHARCSEG"]:
            mass, segment = map(int, fields[1:3])
            source_segment_arcs[mass][segment] = fixed(fields[3])

    for mass in sorted(curves):
        segments = {
            segment: tuple(points[index] for index in range(4))
            for segment, points in curves[mass].items()
        }
        if sorted(segments) != list(range(len(segments))):
            raise ValueError(f"mass {mass}: non-contiguous path segments")
        cumulative = [0]
        for segment in range(len(segments)):
            cumulative.append(cumulative[-1] + metapost_arc_length_fixed(segments[segment]))
        source = knots[mass]
        if source_arcs[mass]:
            direct = source_arcs[mass]
            direct_count = min(len(source), len(direct))
            direct_errors = [
                source[index][1] - direct.get(source[index][0], 0)
                for index in range(direct_count)
            ]
            exact = sum(error == 0 for error in direct_errors)
            maximum = max((abs(error) for error in direct_errors), default=0)
            print(f"mass {mass}: source q knots/direct MetaPost subpath arcs "
                  f"{len(source)}/{len(direct)}; exact matches {exact}/{direct_count}; "
                  f"max error {maximum} fixed units")
            for index, error in enumerate(direct_errors):
                if error:
                    print(f"  knot {source[index][0]}: source-q minus direct path arc "
                          f"{error} fixed units")
            # Keep the cubic sum as a separate diagnostic. MetaPost evaluates
            # arclength(subpath (0, i) of p) directly; summing independently
            # rounded cubic estimates is not a substitute for that value.
            common = min(len(source), len(cumulative))
            estimator_errors = [source[index][1] - cumulative[index]
                                for index in range(common)]
            if estimator_errors and any(estimator_errors):
                print(f"  separate cubic-arc sum differs from source q by "
                      f"max {max(map(abs, estimator_errors))} fixed units")
            if source_segment_arcs[mass]:
                source_increments = [
                    source[index + 1][1] - source[index][1]
                    for index in range(min(len(source) - 1,
                                           len(source_segment_arcs[mass])))
                ]
                segment_arcs = [source_segment_arcs[mass][index]
                                for index in range(len(source_increments))]
                segment_errors = [a - b for a, b in
                                  zip(source_increments, segment_arcs)]
                exact_segments = sum(error == 0 for error in segment_errors)
                max_segment_error = max(map(abs, segment_errors), default=0)
                print(f"  q-knot increments/direct MetaPost segment arcs "
                      f"exact {exact_segments}/{len(segment_errors)}; "
                      f"max difference {max_segment_error} fixed units")
                estimator_segment_errors = [
                    source_segment_arcs[mass][segment]
                    - metapost_arc_length_fixed(segments[segment])
                    for segment in range(min(len(segments),
                                             len(source_segment_arcs[mass])))
                ]
                if any(estimator_segment_errors):
                    print(f"  direct MetaPost/cubic-estimator segment arcs "
                          f"max difference "
                          f"{max(map(abs, estimator_segment_errors))} fixed units")
                    for segment, error in enumerate(estimator_segment_errors):
                        if error:
                            print(f"    segment {segment}: direct-minus-estimator "
                                  f"{error} fixed units")
            continue
        count = min(len(source), len(cumulative))
        errors = [(index, source[index][1] - cumulative[index])
                  for index in range(count)]
        exact = sum(error == 0 for _, error in errors)
        maximum = max((abs(error) for _, error in errors), default=0)
        increments = [errors[index][1] - errors[index - 1][1]
                      for index in range(1, len(errors))]
        increment_max = max(map(abs, increments), default=0)
        increment_mean = (sum(map(abs, increments)) / len(increments)
                          if increments else 0)
        print(f"mass {mass}: source q knots/path boundaries {len(source)}/{len(cumulative)}; "
              f"exact cumulative-arc matches {exact}/{count}; max error {maximum} fixed units; "
              f"increment error mean/max {increment_mean:.2f}/{increment_max} units")
        for index, error in errors:
            if error:
                print(f"  knot {index}: source-minus-cubic-arc {error} fixed units")
        if increment_max > 0:
            largest = sorted(range(len(increments)),
                             key=lambda index: abs(increments[index]),
                             reverse=True)[:8]
            for index in largest:
                if increments[index]:
                    print(f"  segment {index}: source-minus-cubic arc increment "
                          f"{increments[index]} fixed units")


if __name__ == "__main__":
    main()
