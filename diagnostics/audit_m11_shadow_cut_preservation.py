#!/usr/bin/env python3
"""Compare shadowCut endpoints with the original source and paired Typst lane."""

import argparse
import math
from collections import defaultdict
from pathlib import Path

from extract_m11_typst_q_inputs import PAIRS, cubic, read_source


def read_pre_cut_curves(path):
    curves = defaultdict(lambda: defaultdict(dict))
    for line in path.read_text().splitlines():
        fields = line.split()
        if not fields or fields[0] not in ("M11CURVEA", "M11CURVEB"):
            continue
        key = (int(fields[1]), int(fields[2]))
        index = int(fields[3])
        pair = tuple(map(float, fields[4:8]))
        if fields[0] == "M11CURVEA":
            curves[key][index].update({0: pair[0:2], 1: pair[2:4]})
        else:
            curves[key][index].update({2: pair[0:2], 3: pair[2:4]})
    return {
        key: [tuple(curves[key][i][control] for control in range(4))
              for i in sorted(curves[key])]
        for key in curves
    }


def read_post_cut_curves(path):
    curves = defaultdict(lambda: defaultdict(dict))
    for line in path.read_text().splitlines():
        fields = line.split()
        if not fields or fields[0] not in ("M11POSTCURVEA", "M11POSTCURVEB"):
            continue
        key = (int(fields[1]), int(fields[2]))
        index = int(fields[3])
        pair = tuple(map(float, fields[4:8]))
        if fields[0] == "M11POSTCURVEA":
            curves[key][index].update({0: pair[0:2], 1: pair[2:4]})
        else:
            curves[key][index].update({2: pair[0:2], 3: pair[2:4]})
    return {
        key: [tuple(curves[key][i][control] for control in range(4))
              for i in sorted(curves[key])]
        for key in curves
    }


def mapped_cut_time(current_time, previous_base_times):
    base_time = current_time
    for _ in range(len(previous_base_times) + 1):
        updated = current_time - 2 * sum(t < base_time for t in previous_base_times)
        if abs(updated - base_time) < 1e-12:
            return updated
        base_time = updated
    return base_time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_trace", type=Path)
    parser.add_argument("--trim", type=float, default=0.05)
    args = parser.parse_args()

    cuts, _, _, _, _, _, _ = read_source(args.source_trace)
    pre_curves = read_pre_cut_curves(args.source_trace)
    post_curves = read_post_cut_curves(args.source_trace)
    for key, pair in PAIRS.items():
        if key not in cuts or key not in pre_curves:
            continue
        prior = []
        print(f"call/lane={key[0]}/{key[1]} paired={pair}")
        for current_time, _length in cuts[key]:
            if current_time < 0:
                continue
            source_time = mapped_cut_time(current_time, prior)
            endpoints = (source_time - args.trim, source_time + args.trim)
            for side, time in zip(("before", "after"), endpoints):
                curve_index = min(len(pre_curves[key]) - 1,
                                  max(0, int(math.floor(time))))
                source_point = cubic(pre_curves[key][curve_index],
                                     time - curve_index)
                nearest_post = min(
                    (math.dist(source_point, point), curve_i, control)
                    for curve_i, curve in enumerate(post_curves[key])
                    for control, point in ((0, curve[0]), (3, curve[3]))
                )
                print(f"  cut={current_time:.5f} source-time={source_time:.5f} "
                      f"{side}={time:.5f} "
                      f"pre-to-post={nearest_post[0]:.8g}mm "
                      f"post-endpoint={nearest_post[1]}:{nearest_post[2]}")
            prior.append(source_time)


if __name__ == "__main__":
    main()
