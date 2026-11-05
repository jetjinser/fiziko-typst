#!/usr/bin/env python3
"""Map source post-shadow lane cubic endpoints to the paired Typst lane."""

import argparse
import math
from pathlib import Path

from extract_m11_typst_q_inputs import PAIRS, read_source, typst_lane_map


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_trace", type=Path)
    parser.add_argument("typst_trace", type=Path)
    parser.add_argument("--samples-per-cubic", type=int, default=64)
    args = parser.parse_args()

    post_curves = read_source(args.source_trace)[6]
    lanes = typst_lane_map(args.typst_trace, dense=True)
    for key, pair in PAIRS.items():
        points = lanes[pair]
        scale = args.samples_per_cubic
        curve_list = post_curves[key]
        previous = 0.0
        errors = []
        cut_endpoints = []
        for curve_index, curve in enumerate(curve_list):
            for control, point in ((0, curve[0]), (3, curve[3])):
                best = None
                for index in range(max(0, int(previous)), len(points) - 1):
                    a, b = points[index], points[index + 1]
                    dx, dy = b[0] - a[0], b[1] - a[1]
                    denom = dx * dx + dy * dy
                    lower = max(0.0, previous - index)
                    fraction = 0.0 if denom == 0 else max(lower, min(1.0,
                        ((point[0] - a[0]) * dx + (point[1] - a[1]) * dy)
                        / denom))
                    projected = (a[0] + fraction * dx,
                                 a[1] + fraction * dy)
                    distance = math.dist(projected, point)
                    if best is None or distance < best[0]:
                        best = (distance, index + fraction)
                error, path_index = best
                lane_time = path_index / scale
                errors.append(error)
                if abs(lane_time - round(lane_time)) > 0.001:
                    cut_endpoints.append((curve_index, control, lane_time, error))
                previous = path_index
        print(f"call/lane={key[0]}/{key[1]} paired={pair} "
              f"post-curves={len(curve_list)} "
              f"endpoint-error-mean/max="
              f"{sum(errors) / len(errors):.8g}/{max(errors):.8g}mm")
        for curve_index, control, lane_time, error in cut_endpoints:
            print(f"  noninteger endpoint post={curve_index}:{control} "
                  f"lane-time={lane_time:.8f} distance={error:.8g}mm")


if __name__ == "__main__":
    main()
