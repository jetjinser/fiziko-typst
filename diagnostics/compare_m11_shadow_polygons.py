#!/usr/bin/env python3
"""Compare source M11 self-shadow hits and tube contours with Typst geometry.

Usage: compare_m11_shadow_polygons.py MPOST_LOG [TYPOGRAPHY_TRACE_JSON]
"""

import argparse
import json
import math
from collections import defaultdict
from pathlib import Path


# Under-layer source tube call -> (upper-layer tube outline id, Typst path id).
SHADOW_PAIRS = {
    4: (4, (0, 0)),
    5: (6, (0, 2)),
    6: (2, (1, 1)),
}
OUTLINE_PAIRS = {
    (1, 2): (1, 1),
    (1, 4): (0, 0),
    (1, 6): (0, 2),
    (-1, 1): (1, 0),
    (-1, 3): (1, 2),
    (-1, 5): (0, 1),
}


def read_source(path: Path):
    outlines = defaultdict(list)
    samples = defaultdict(list)
    hits = set()
    depths = {}
    for line in path.read_text().splitlines():
        f = line.split()
        if not f:
            continue
        if f[0] == "M11TO":
            outlines[(int(f[1]), int(f[2]))].append((float(f[4]), float(f[5])))
        elif f[0] == "M11LIGHT":
            samples[(int(f[1]), int(f[2]))].append((float(f[3]), float(f[4])))
        elif f[0] == "M11SHADOW":
            hits.add((int(f[1]), int(f[2]), float(f[3]), float(f[4])))
        elif f[0] == "M11CUTSHADOW":
            # call, lane, shadow-index, current-depth, shadow-depth, light xyz
            depths[(int(f[1]), int(f[2]))] = (
                float(f[4]), float(f[5]), tuple(map(float, f[6:9])))
    return outlines, samples, hits, depths


def inside(point, polygon):
    x, y = point
    result = False
    for (ax, ay), (bx, by) in zip(polygon, polygon[1:] + polygon[:1]):
        if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
            result = not result
    return result


def point_segment_distance(point, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    denom = dx * dx + dy * dy
    t = 0.0 if denom == 0 else max(0.0, min(1.0,
        ((point[0] - a[0]) * dx + (point[1] - a[1]) * dy) / denom))
    return math.dist(point, (a[0] + t * dx, a[1] + t * dy))


def directed_distances(a, b):
    edges = list(zip(b, b[1:] + b[:1]))
    return [min(point_segment_distance(p, q, r) for q, r in edges) for p in a]


def read_typst(path: Path):
    data = json.loads(path.read_text())
    while data and isinstance(data[0], list):
        data = data[0]
    return {(row["strand"], row["segment"]): row["silhouette"] for row in data}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("typst_trace", nargs="?", type=Path)
    args = parser.parse_args()
    outlines, samples, hits, depths = read_source(args.source_log)

    typst = read_typst(args.typst_trace) if args.typst_trace else None
    for call, (outline_id, typst_id) in SHADOW_PAIRS.items():
        source_counts = [0, 0, 0, 0]
        typst_counts = [0, 0, 0, 0]
        for (sample_call, lane), points in samples.items():
            if sample_call != call:
                continue
            current_depth, shadow_depth, light = depths[(call, lane)]
            dx = (current_depth - shadow_depth) * light[0] * light[2]
            dy = (current_depth - shadow_depth) * light[1] * light[2]
            polygon = outlines[(1, outline_id)]
            for x, y in points:
                truth = (call, lane, x, y) in hits
                source_predicted = inside((x - dx, y - dy), polygon)
                classify(source_counts, truth, source_predicted)
                if typst is not None:
                    classify(typst_counts, truth,
                             inside((x - dx, y - dy), typst[typst_id]))
        tp, fp, fn, tn = source_counts
        precision = tp / max(1, tp + fp)
        recall = tp / max(1, tp + fn)
        print(f"source-call={call} outline=(1,{outline_id}) "
              f"tp/fp/fn/tn={tp}/{fp}/{fn}/{tn} "
              f"precision/recall={precision:.6f}/{recall:.6f}")
        if typst is not None:
            tp, fp, fn, tn = typst_counts
            precision = tp / max(1, tp + fp)
            recall = tp / max(1, tp + fn)
            print(f"  Typst silhouette={typst_id} "
                  f"tp/fp/fn/tn={tp}/{fp}/{fn}/{tn} "
                  f"precision/recall={precision:.6f}/{recall:.6f}")

    if typst is not None:
        for source_id, typst_id in OUTLINE_PAIRS.items():
            source = outlines[source_id]
            candidate = [tuple(point) for point in typst[typst_id]]
            forward = directed_distances(source, candidate)
            reverse = directed_distances(candidate, source)
            print(f"outline={source_id} typst={typst_id} "
                  f"source-to-typst mean/max="
                  f"{sum(forward) / len(forward):.6f}/{max(forward):.6f}mm "
                  f"typst-to-source mean/max="
                  f"{sum(reverse) / len(reverse):.6f}/{max(reverse):.6f}mm")


def classify(counts, truth, predicted):
    if truth and predicted:
        counts[0] += 1
    elif predicted:
        counts[1] += 1
    elif truth:
        counts[2] += 1
    else:
        counts[3] += 1


if __name__ == "__main__":
    main()
