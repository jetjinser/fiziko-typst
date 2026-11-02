#!/usr/bin/env python3
"""Export traced post-shadow cubic paths and integer width callbacks as JSON.

Usage: extract_m11_shadow_brush_inputs.py MPOST_LOG OUTPUT_JSON
"""

import argparse
import json
from collections import defaultdict
from pathlib import Path

from audit_m11_q_arclength import arc_length, read_trace


def cubic(points, t):
    p0, p1, p2, p3 = points
    u = 1 - t
    return tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d
                 for a, b, c, d in zip(p0, p1, p2, p3))


MP_UNIT_MM = 25.4 / 72


def sampled_curve(points, steps):
    return [cubic(points, i / steps) for i in range(steps + 1)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log")
    parser.add_argument("output")
    parser.add_argument("--samples-per-cubic", type=int, default=4,
                        choices=(1, 2, 4, 8, 16, 32))
    parser.add_argument("--arc-mode", choices=("metapost", "integrated"),
                        default="metapost",
                        help="use traced MetaPost arc knots or integrate the traced cubics")
    parser.add_argument("--arc-json", type=Path,
                        help="use per-cubic arc lengths emitted by m11_fixed_arc_check.typ")
    args = parser.parse_args()
    log_path, output_path = args.log, args.output
    samples_per_cubic = args.samples_per_cubic
    curves = defaultdict(lambda: defaultdict(dict))
    callback_time = {}
    callbacks = defaultdict(dict)
    source_q = defaultdict(lambda: defaultdict(dict))
    source_arcs = defaultdict(dict)
    typst_arcs = {}
    if args.arc_json:
        arc_result = json.loads(args.arc_json.read_text())
        typst_arcs = {(item["call"], item["lane"]): item["arcs"]
                      for item in arc_result}
    exact_curves = {}
    if args.arc_mode == "integrated":
        exact_curves, _qcurves, _trace_arcs = read_trace(Path(log_path))
    lane_calls = {}
    lane_order = []
    for line_number, line in enumerate(Path(log_path).read_text().splitlines()):
        f = line.split()
        if not f:
            continue
        if f[0] == "M11POSTCURVEA":
            key = (int(f[1]), int(f[2]))
            index = int(f[3])
            curves[key][index]["p0"] = tuple(map(float, f[4:6]))
            curves[key][index]["p1"] = tuple(map(float, f[6:8]))
        elif f[0] == "M11POSTCURVEB":
            key = (int(f[1]), int(f[2]))
            index = int(f[3])
            curves[key][index]["p2"] = tuple(map(float, f[4:6]))
            curves[key][index]["p3"] = tuple(map(float, f[6:8]))
        elif f[0] == "M11WIDTHINPUT":
            key = (int(f[1]), int(f[2]))
            callback_time[key] = int(f[4])
            callbacks[key][callback_time[key]] = {
                "max_width": float(f[5]),
                "line_density": float(f[6]),
                "tube_width": float(f[7]),
            }
        elif f[0] == "M11LIGHT":
            key = (int(f[1]), int(f[2]))
            time = callback_time.pop(key)
            callbacks[key][time]["normal"] = list(map(float, f[5:8]))
            callbacks[key][time]["lightness"] = float(f[8])
        elif f[0] == "M11WIDTHFIX":
            key = (int(f[1]), int(f[2]))
            time = int(f[3])
            callbacks[key][time]["width_fixed"] = int(f[4]) * 256 + int(f[5])
        elif f[0] == "M11POSTARC":
            key = (int(f[1]), int(f[2]))
            time = int(f[3]) + 1
            source_arcs[key][time] = int(f[4]) * 65536 + int(f[5]) * 256 + int(f[6])
        elif f[0] == "M11BQPT":
            key = (int(f[1]), int(f[2]))
            depth, index, control = map(int, f[3:6])
            if depth == 0:
                source_q[key][index][control] = (
                    int(f[6]) * 256 + int(f[7]),
                    int(f[8]) * 256 + int(f[9]),
                )
        elif f[0] == "M11LANE":
            key = (int(f[1]), int(f[2]))
            lane_calls[key] = int(f[3])
            lane_order.append((line_number, key))

    entries = []
    rng_cursor = 4639
    for _, key in lane_order:
        source_calls = lane_calls[key]
        path_curves = curves[key]
        width_samples = callbacks[key]
        if not path_curves or not width_samples:
            rng_cursor += source_calls
            continue
        indices = sorted(path_curves)
        if indices != list(range(len(indices))):
            raise ValueError(f"non-contiguous curve indices for {key}: {indices}")
        path_points = []
        widths = []
        path_times = []
        for i in indices:
            controls = path_curves[i]
            if set(controls) != {"p0", "p1", "p2", "p3"}:
                raise ValueError(f"incomplete cubic for {key}, segment {i}")
            if i not in width_samples or i + 1 not in width_samples:
                raise ValueError(f"missing integer callback for {key}, segment {i}")
            control_points = [controls[name] for name in ("p0", "p1", "p2", "p3")]
            # Integrate cubic arclength densely, but retain evenly spaced
            # geometry samples in source path time. offsetPathTemplate joins
            # integer-time width callbacks with `--`, so its width y-value is
            # linear in path time, not in the centerline's arc length.
            integration_points = sampled_curve(control_points, 32)
            def width(sample):
                if "width_fixed" in sample:
                    # M11WIDTHFIX records raw MetaPost bp coordinates. Convert
                    # the source 16.16 grid to Typst millimetres only after
                    # decoding it, preserving the finer source width lattice.
                    return sample["width_fixed"] / 65536 * MP_UNIT_MM
                return sample["max_width"] * sample["lightness"]

            w0 = width(width_samples[i])
            w1 = width(width_samples[i + 1])
            if i == 0:
                path_points.append(integration_points[0])
                widths.append(w0)
                path_times.append(float(i))
            for sample_index in range(1, samples_per_cubic + 1):
                integration_index = sample_index * (32 // samples_per_cubic)
                sample = integration_points[integration_index]
                fraction = sample_index / samples_per_cubic
                path_points.append(sample)
                widths.append(w0 * (1 - fraction) + w1 * fraction)
                path_times.append(i + sample_index / samples_per_cubic)
        if args.arc_json:
            lengths = typst_arcs.get(key)
            if lengths is None:
                arc_values = source_arcs[key]
            else:
                if len(lengths) != len(indices):
                    raise ValueError(f"incomplete Typst arc lengths for {key}")
                arc_values = {}
                cumulative_arc = 0
                for index, length in enumerate(lengths, start=1):
                    cumulative_arc += int(length)
                    arc_values[index] = cumulative_arc
        elif args.arc_mode == "metapost":
            arc_values = source_arcs[key]
        else:
            arc_values = {}
            cumulative_arc = 0.0
            for i in indices:
                control_map = exact_curves[(key[0], key[1], i)]
                cumulative_arc += arc_length([control_map[j] for j in range(4)])
                arc_values[i + 1] = int(round(cumulative_arc * 65536))
        entries.append({
            "call": key[0], "lane": key[1], "source_calls": source_calls,
            "rng_offset": rng_cursor,
            "source_path_segments": len(indices), "points": path_points,
            "widths": widths, "param_times": path_times,
            "source_arc_fixed": (
                [0] + [arc_values[i] for i in range(1, len(indices) + 1)]
                if len(arc_values) == len(indices) else None
            ),
            "source_q_fixed": [
                [source_q[key][index][control] for control in range(4)]
                for index in sorted(source_q[key])
            ] if source_q[key] and all(
                set(source_q[key][index]) == {0, 1, 2, 3}
                for index in source_q[key]
            ) else None,
        })
        rng_cursor += source_calls
    def number(value):
        return f"{value:.9f}"

    def tuple_expr(values):
        return "(" + ", ".join(values) + ")"

    lines = ["#let m11-shadow-inputs = ("]
    for entry in entries:
        points = tuple_expr(tuple_expr(tuple(number(x) for x in point))
                            for point in entry["points"])
        widths = tuple_expr(number(width) for width in entry["widths"])
        param_times = tuple_expr(number(time) for time in entry["param_times"])
        source_q_fixed = (
            "none" if entry["source_q_fixed"] is None else
            tuple_expr(tuple_expr(
                "(" + str(point[0]) + ", " + str(point[1]) + ")"
                for point in curve
            ) for curve in entry["source_q_fixed"])
        )
        source_arc_fixed = (
            "none" if entry["source_arc_fixed"] is None else
            tuple_expr(str(value) for value in entry["source_arc_fixed"])
        )
        lines.append(
            f"  (call: {entry['call']}, lane: {entry['lane']}, "
            f"source-calls: {entry['source_calls']}, rng-offset: {entry['rng_offset']}, "
            f"source-path-segments: {entry['source_path_segments']}, "
            f"points: {points}, widths: {widths}, param-times: {param_times}, "
            f"source-arc-fixed: {source_arc_fixed}, "
            f"source-q-fixed: {source_q_fixed}),"
        )
    lines.append(")")
    Path(output_path).write_text("\n".join(lines) + "\n")
    print(f"exported {len(entries)} source lane inputs to {output_path}")
    for entry in entries:
        print(f"call={entry['call']} lane={entry['lane']} "
              f"segments={entry['source_path_segments']} "
              f"points={len(entry['points'])} source-calls={entry['source_calls']}")


if __name__ == "__main__":
    main()
