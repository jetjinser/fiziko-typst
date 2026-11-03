#!/usr/bin/env python3
"""Build post-shadow M11 q-replay inputs from actual Typst lane samples."""

import json
import math
from collections import defaultdict
from pathlib import Path


# Source tube-call/lane to the geometrically paired strand-knot inner lane.
PAIRS = {
    (4, 2): (1, 0, 5),
    (4, 6): (1, 0, 1),
    (5, 2): (1, 2, 5),
}
SAMPLES_PER_CUBIC = 4


def source_time_at(segments, time):
    if time >= len(segments):
        return segments[-1][1]
    i = max(0, int(time))
    f = time - i
    return segments[i][0] * (1 - f) + segments[i][1] * f


def splice(segments, cut_time, half_gap=0.05):
    start, end = cut_time - half_gap, cut_time + half_gap
    si, ei = int(start // 1), int(end // 1)
    sf, ef = start - si, end - ei
    source_start = source_time_at(segments, start)
    source_end = source_time_at(segments, end)
    out = list(segments[:si])
    if sf > 1e-9:
        out.append((segments[si][0], source_start))
    out.append((source_start, source_end))
    if ef > 1e-9:
        out.append((source_end, segments[ei][1]))
    suffix = ei + 1 if ef > 1e-9 else ei
    out.extend(segments[suffix:])
    return out


def read_source(path):
    cuts = defaultdict(list)
    widths = defaultdict(dict)
    lane_calls = {}
    lane_order = []
    post_lengths = {}
    source_arcs = defaultdict(dict)
    post_curves = defaultdict(lambda: defaultdict(dict))
    for line_index, line in enumerate(path.read_text().splitlines()):
        f = line.split()
        if not f:
            continue
        if f[0] == "M11CUT":
            key = (int(f[1]), int(f[2]))
            cuts[key].append((float(f[4]), int(round(float(f[6])))))
        elif f[0] == "M11WIDTHFIX":
            key = (int(f[1]), int(f[2]))
            widths[key][int(f[3])] = int(f[4]) * 256 + int(f[5])
        elif f[0] == "M11LANE":
            key = (int(f[1]), int(f[2]))
            lane_calls[key] = int(f[3])
            lane_order.append((line_index, key))
        elif f[0] == "M11POSTPARAM":
            key = (int(f[1]), int(f[2]))
            post_lengths[key] = int(f[3])
        elif f[0] == "M11POSTARC":
            key = (int(f[1]), int(f[2]))
            source_arcs[key][int(f[3]) + 1] = (
                int(f[4]) * 65536 + int(f[5]) * 256 + int(f[6]))
        elif f[0] == "M11POSTFIX":
            key = (int(f[1]), int(f[2]))
            curve, control = int(f[3]), int(f[4])
            post_curves[key][curve][control] = (
                (int(f[5]) + int(f[6]) / 256 + int(f[7]) / 65536)
                * 25.4 / 72,
                (int(f[8]) + int(f[9]) / 256 + int(f[10]) / 65536)
                * 25.4 / 72,
            )
    offsets = {}
    cursor = 4639
    for _, key in lane_order:
        offsets[key] = cursor
        cursor += lane_calls[key]
    curves = {key: [tuple(post_curves[key][i][j] for j in range(4))
                    for i in sorted(post_curves[key])]
              for key in post_curves}
    return cuts, widths, lane_calls, offsets, post_lengths, source_arcs, curves


def typst_lane_map(path, dense=False):
    traces = json.loads(path.read_text())
    out = {}
    for trace in traces:
        for lane in trace["inner-lanes"]:
            key = (trace["strand"], trace["segment"], lane["lane"])
            field = "dense-points" if dense else "points"
            out[key] = [tuple(map(float, point)) for point in lane[field]]
    return out


def sample(points, source_time, samples_per_cubic=SAMPLES_PER_CUBIC):
    at = max(0.0, min(len(points) - 1, source_time * samples_per_cubic))
    i = int(at)
    if i + 1 >= len(points):
        return points[-1]
    f = at - i
    return tuple(points[i][axis] * (1 - f) + points[i + 1][axis] * f
                 for axis in (0, 1))


def cubic(points, t):
    p0, p1, p2, p3 = points
    u = 1 - t
    return tuple(u**3 * a + 3 * u*u*t*b + 3*u*t*t*c + t**3*d
                 for a, b, c, d in zip(p0, p1, p2, p3))


def export(source_log, typst_trace, output, dense=False, dense_factor=4):
    cuts, widths, calls, offsets, post_lengths, source_arcs, source_curves = read_source(source_log)
    samples_per_cubic = SAMPLES_PER_CUBIC * dense_factor if dense else SAMPLES_PER_CUBIC
    lanes = typst_lane_map(typst_trace, dense=dense)
    records = []
    for key, pair in PAIRS.items():
        if key not in widths or key not in cuts or key not in offsets:
            raise ValueError(f"missing source callbacks/cuts/RNG data for {key}")
        if sorted(widths[key]) != list(range(len(widths[key]))):
            raise ValueError(f"non-contiguous source callback widths for {key}")
        if sorted(widths[key])[-1] != post_lengths[key]:
            raise ValueError(f"callback/path length mismatch for {key}: "
                             f"{len(widths[key])} widths, path={post_lengths[key]}")
        center = lanes[pair]
        segments = [(float(i), float(i + 1)) for i in range(len(center) // samples_per_cubic)]
        expected_initial = cuts[key][0][1]
        if len(segments) != expected_initial:
            raise ValueError(f"paired Typst lane {pair} has {len(segments)} cubics; "
                             f"source starts with {expected_initial}")
        for cut_time, _length in cuts[key]:
            if cut_time >= 0:
                segments = splice(segments, cut_time)
        if len(segments) != post_lengths[key]:
            raise ValueError(f"source splice map for {key} has {len(segments)} segments, "
                             f"expected {post_lengths[key]}")
        if len(source_curves.get(key, ())) != post_lengths[key]:
            raise ValueError(f"source post-shadow cubic count mismatch for {key}")
        path = []
        path_times = []
        ws = []
        point_errors = []
        segment_errors = defaultdict(list)
        for i in range(post_lengths[key]):
            for q in range(samples_per_cubic):
                post_time = i + q / samples_per_cubic
                source_time = source_time_at(segments, post_time)
                point = sample(center, source_time, samples_per_cubic)
                reference = cubic(source_curves[key][i], q / samples_per_cubic)
                error = math.dist(point, reference)
                point_errors.append(error)
                segment_errors[i].append(error)
                path.append(point)
                path_times.append(post_time)
                w0, w1 = widths[key][i], widths[key][i + 1]
                ws.append((w0 * (1 - q / samples_per_cubic)
                           + w1 * (q / samples_per_cubic)) / 65536
                          * 25.4 / 72)
        end_time = float(post_lengths[key])
        endpoint = sample(center, source_time_at(segments, end_time), samples_per_cubic)
        endpoint_error = math.dist(endpoint, source_curves[key][-1][-1])
        point_errors.append(endpoint_error)
        segment_errors[post_lengths[key] - 1].append(endpoint_error)
        path.append(endpoint)
        path_times.append(end_time)
        ws.append(widths[key][post_lengths[key]] / 65536 * 25.4 / 72)
        segment_maxima = sorted(
            ((max(values), index) for index, values in segment_errors.items()),
            reverse=True)[:4]
        records.append({
            "call": key[0], "lane": key[1], "source-calls": calls[key],
            "rng-offset": offsets[key], "segments": post_lengths[key],
            "points": path, "widths": ws, "param-times": path_times,
            "source-width-fixed": [widths[key][i]
                                    for i in range(post_lengths[key] + 1)],
            "source-arc-fixed": [0] + [source_arcs[key][i]
                                        for i in range(1, post_lengths[key] + 1)],
            "geometry-error-max": max(point_errors),
            "geometry-error-mean": sum(point_errors) / len(point_errors),
            "geometry-error-segments": segment_maxima,
        })

    def scalar(value):
        return f"{value:.10f}"

    lines = ["#let m11-production-q-inputs = ("]
    for r in records:
        points = ", ".join("(" + scalar(x) + ", " + scalar(y) + ")"
                            for x, y in r["points"])
        widths_text = ", ".join(scalar(x) for x in r["widths"])
        times = ", ".join(scalar(x) for x in r["param-times"])
        fixed = ", ".join(map(str, r["source-width-fixed"]))
        source_arc = ", ".join(map(str, r["source-arc-fixed"]))
        lines.append(
            f"  (call: {r['call']}, lane: {r['lane']}, "
            f"source-calls: {r['source-calls']}, rng-offset: {r['rng-offset']}, "
            f"segments: {r['segments']}, samples-per-segment: {samples_per_cubic}, points: ({points}), "
            f"widths: ({widths_text}), param-times: ({times}), "
            f"source-width-fixed: ({fixed}), source-arc-fixed: ({source_arc})),")
    lines.append(")")
    output.write_text("\n".join(lines) + "\n")
    print(f"exported {len(records)} geometry-paired production lane inputs")
    for r in records:
        print(f"call={r['call']} lane={r['lane']} segments={r['segments']} "
              f"source-calls={r['source-calls']} rng-offset={r['rng-offset']} "
              f"geometry-error-max/mean={r['geometry-error-max']:.6f}/"
              f"{r['geometry-error-mean']:.6f}mm top={r['geometry-error-segments']}")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_trace", type=Path)
    parser.add_argument("typst_trace", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--dense", action="store_true",
                        help="read the densely sampled lane path from the trace")
    parser.add_argument("--dense-factor", type=int, default=4,
                        help="number of direct curve samples between input knots")
    args = parser.parse_args()
    export(args.source_trace, args.typst_trace, args.output, dense=args.dense,
           dense_factor=args.dense_factor)
