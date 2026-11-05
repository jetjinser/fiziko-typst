#!/usr/bin/env python3
"""Compare shadowCut connector cubics with the corresponding pre-cut curves."""

import argparse
import math
from collections import defaultdict
from pathlib import Path

from audit_m11_shadow_cut_preservation import read_post_cut_curves, read_pre_cut_curves
from extract_m11_typst_q_inputs import PAIRS


HALF_GAP = 0.05


def source_cut_records(path):
    records = defaultdict(list)
    for line in path.read_text().splitlines():
        f = line.split()
        if len(f) == 8 and f[0] == "M11CUT":
            records[int(f[1]), int(f[2])].append((float(f[4]), float(f[6])))
    return records


def source_time_at(segments, time):
    if time >= len(segments):
        return segments[-1][1]
    index = max(0, int(time))
    fraction = time - index
    start, end = segments[index][:2]
    return start * (1 - fraction) + end * fraction


def splice(segments, cut_time):
    start_time, end_time = cut_time - HALF_GAP, cut_time + HALF_GAP
    start_index, end_index = int(start_time), int(end_time)
    start_fraction = start_time - start_index
    end_fraction = end_time - end_index
    source_start = source_time_at(segments, start_time)
    source_end = source_time_at(segments, end_time)
    result = list(segments[:start_index])
    if start_fraction > 1e-9:
        result.append((segments[start_index][0], source_start, False))
    result.append((source_start, source_end, True))
    if end_fraction > 1e-9:
        result.append((source_end, segments[end_index][1], False))
    suffix = end_index + 1 if end_fraction > 1e-9 else end_index
    result.extend((start, end, connector)
                  for start, end, connector in segments[suffix:])
    return result


def mix(a, b, t):
    return tuple(x * (1 - t) + y * t for x, y in zip(a, b))


def split(curve, t):
    a, b, c = (mix(curve[i], curve[i + 1], t) for i in range(3))
    d, e = mix(a, b, t), mix(b, c, t)
    f = mix(d, e, t)
    return ((curve[0], a, d, f), (f, e, c, curve[3]))


def subsegment(curve, start, end):
    prefix = curve if end >= 1 - 1e-12 else split(curve, end)[0]
    return prefix if start <= 1e-12 else split(prefix, start / end)[1]


def audit(path):
    pre = read_pre_cut_curves(path)
    post = read_post_cut_curves(path)
    cuts = source_cut_records(path)
    for key in PAIRS:
        curves = pre[key]
        segments = [(float(i), float(i + 1), False)
                    for i in range(len(curves))]
        for cut_time, path_length in cuts[key]:
            if 0.1 < cut_time < path_length - 0.1:
                segments = splice(segments, cut_time)
        connector_indexes = [i for i, item in enumerate(segments) if item[2]]
        print(f"call/lane={key[0]}/{key[1]} source-connectors="
              f"{len(connector_indexes)}")
        for post_index in connector_indexes:
            start, end, _is_connector = segments[post_index]
            first, last = int(math.floor(start)), int(math.floor(end - 1e-12))
            if first != last:
                print(f"  post-segment={post_index} source-time="
                      f"[{start:.5f},{end:.5f}] crosses source cubic knot; "
                      "connector control comparison omitted")
                continue
            curve_index = min(first, len(curves) - 1)
            expected = subsegment(curves[curve_index], start - curve_index,
                                  end - curve_index)
            actual = post[key][post_index]
            errors = [math.dist(a, b) for a, b in zip(actual, expected)]
            print(f"  post-segment={post_index} source-time="
                  f"[{start:.5f},{end:.5f}] controls max error="
                  f"{max(errors):.8g} mm")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_trace", type=Path)
    args = parser.parse_args()
    audit(args.source_trace)


if __name__ == "__main__":
    main()
