#!/usr/bin/env python3
"""Export traced post-shadow cubic paths and integer width callbacks as JSON.

Usage: extract_m11_shadow_brush_inputs.py MPOST_LOG OUTPUT_JSON
"""

import argparse
from collections import defaultdict
from pathlib import Path


def cubic(points, t):
    p0, p1, p2, p3 = points
    u = 1 - t
    return tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d
                 for a, b, c, d in zip(p0, p1, p2, p3))


def sampled_curve(points, steps):
    samples = [cubic(points, i / steps) for i in range(steps + 1)]
    lengths = [0.0]
    for a, b in zip(samples, samples[1:]):
        lengths.append(lengths[-1] + ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5)
    return samples, lengths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log")
    parser.add_argument("output")
    parser.add_argument("--samples-per-cubic", type=int, default=4,
                        choices=(1, 2, 4, 8, 16, 32))
    args = parser.parse_args()
    log_path, output_path = args.log, args.output
    samples_per_cubic = args.samples_per_cubic
    curves = defaultdict(lambda: defaultdict(dict))
    callback_time = {}
    callbacks = defaultdict(dict)
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
            # Integrate cubic arclength densely, but retain four geometry
            # samples per source unit and map them back to source path time.
            integration_points, lengths = sampled_curve(control_points, 32)
            segment_length = lengths[-1]
            w0 = width_samples[i]["max_width"] * width_samples[i]["lightness"]
            w1 = width_samples[i + 1]["max_width"] * width_samples[i + 1]["lightness"]
            if i == 0:
                path_points.append(integration_points[0])
                widths.append(w0)
                path_times.append(float(i))
            for sample_index in range(1, samples_per_cubic + 1):
                integration_index = sample_index * (32 // samples_per_cubic)
                sample = integration_points[integration_index]
                distance = lengths[integration_index]
                fraction = distance / segment_length if segment_length else 1.0
                path_points.append(sample)
                widths.append(w0 * (1 - fraction) + w1 * fraction)
                path_times.append(i + sample_index / samples_per_cubic)
        entries.append({
            "call": key[0], "lane": key[1], "source_calls": source_calls,
            "rng_offset": rng_cursor,
            "source_path_segments": len(indices), "points": path_points,
            "widths": widths, "param_times": path_times,
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
        lines.append(
            f"  (call: {entry['call']}, lane: {entry['lane']}, "
            f"source-calls: {entry['source_calls']}, rng-offset: {entry['rng_offset']}, "
            f"source-path-segments: {entry['source_path_segments']}, "
            f"points: {points}, widths: {widths}, param-times: {param_times}),"
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
