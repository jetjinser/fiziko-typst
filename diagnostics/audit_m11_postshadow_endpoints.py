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

    *_, post_curves = read_source(args.source_trace)
    lanes = typst_lane_map(args.typst_trace, dense=True)
    for key, pair in PAIRS.items():
        points = lanes[pair]
        scale = args.samples_per_cubic
        curve_list = post_curves[key]
        previous = 0
        errors = []
        cut_endpoints = []
        for curve_index, curve in enumerate(curve_list):
            for control, point in ((0, curve[0]), (3, curve[3])):
                candidates = range(previous, len(points))
                nearest_index = min(
                    candidates,
                    key=lambda index: math.dist(points[index], point),
                )
                error = math.dist(points[nearest_index], point)
                lane_time = nearest_index / scale
                errors.append(error)
                if abs(lane_time - round(lane_time)) > 0.001:
                    cut_endpoints.append((curve_index, control, lane_time, error))
                previous = nearest_index
        print(f"call/lane={key[0]}/{key[1]} paired={pair} "
              f"post-curves={len(curve_list)} "
              f"endpoint-error-mean/max="
              f"{sum(errors) / len(errors):.8g}/{max(errors):.8g}mm")
        for curve_index, control, lane_time, error in cut_endpoints:
            print(f"  noninteger endpoint post={curve_index}:{control} "
                  f"lane-time={lane_time:.8f} distance={error:.8g}mm")


if __name__ == "__main__":
    main()
