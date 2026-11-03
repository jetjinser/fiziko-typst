#!/usr/bin/env python3
"""Compare source M11 lane lightness/width with geometrically paired Typst lanes.

Usage: compare_m11_shading_samples.py MPOST_LOG TYPOGRAPHY_TRACE_JSON
"""

import argparse
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path

MM_PER_BP = 25.4 / 72

# Source tube call/lane -> (strand, section, lane) from the paired centerlines.
PAIRS = {
    (1, 2): (1, 1, 5), (1, 6): (1, 1, 1),
    (2, 2): (0, 0, 5), (2, 6): (0, 0, 1),
    (3, 2): (0, 2, 5), (3, 6): (0, 2, 1),
    (4, 2): (1, 0, 5), (4, 6): (1, 0, 1),
    (5, 2): (1, 2, 5), (5, 6): (1, 2, 1),
    (6, 2): (0, 1, 5), (6, 6): (0, 1, 1),
}


def source_samples(path: Path):
    callback = {}
    width_inputs = {}
    widths = {}
    samples = defaultdict(list)
    shadows = defaultdict(list)
    angles = defaultdict(list)
    center_curves = defaultdict(dict)
    for line in path.read_text().splitlines():
        f = line.split()
        if not f:
            continue
        tag = f[0]
        if tag == "M11WIDTHINPUT":
            key = (int(f[1]), int(f[2]))
            callback[key] = float(f[4])
            width_inputs[key] = {
                "bw1": float(f[3]),
                "max-width": float(f[5]),
                "line-density": float(f[6]),
                "tube-width": float(f[7]),
            }
        elif tag == "M11WIDTHFIX":
            key = (int(f[1]), int(f[2]))
            time = float(f[3])
            widths[(key, time)] = (int(f[4]) * 256 + int(f[5])) / 65536 * MM_PER_BP
        elif tag == "M11LIGHT":
            key = (int(f[1]), int(f[2]))
            time = callback.pop(key)
            samples[key].append({
                "time": time,
                "point": (float(f[3]), float(f[4])),
                "normal": tuple(map(float, f[5:8])),
                "lightness": float(f[8]),
                **width_inputs[key],
            })
        elif tag == "M11ANGLE":
            key = (int(f[1]), int(f[2]))
            angles[key].append(tuple(map(float, f[3:6])))
        elif tag == "M11CENTERA":
            call, segment = int(f[1]), int(f[2])
            center_curves[call][segment] = [
                (float(f[3]), float(f[4])), (float(f[5]), float(f[6])), None, None
            ]
        elif tag == "M11CENTERB":
            call, segment = int(f[1]), int(f[2])
            center_curves[call][segment][2:] = [
                (float(f[3]), float(f[4])), (float(f[5]), float(f[6]))
            ]
        elif tag == "M11SHADOW":
            key = (int(f[1]), int(f[2]))
            shadows[key].append((float(f[3]), float(f[4])))
    for key, rows in samples.items():
        for index, row in enumerate(rows):
            if index >= len(angles[key]):
                raise ValueError(f"missing M11ANGLE for callback {key} sample {index}")
            row["angles"] = angles[key][index]
            row["center-direction-error"] = center_direction_error(
                center_curves[key[0]], row["time"], row["angles"][1]
            )
            row["width"] = widths.get(((key[0], key[1]), row["time"]))
            residual = 1.0
            if row["width"] is not None and key[1] % 2 == 1:
                residual = abs(row["tube-width"] / row["bw1"]
                    - row["line-density"] / 2) / MM_PER_BP
            row["effective-width"] = (
                None if row["width"] is None else row["width"] * residual)
    return samples, shadows


def nearest_sample(point, points, fields):
    best = None
    for i, (a, b) in enumerate(zip(points, points[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]
        denom = dx * dx + dy * dy
        t = 0.0 if denom == 0 else max(0.0, min(1.0,
            ((point[0] - a[0]) * dx + (point[1] - a[1]) * dy) / denom))
        projected = (a[0] + t * dx, a[1] + t * dy)
        distance = math.dist(point, projected)
        if best is None or distance < best[0]:
            values = {}
            for name, series in fields.items():
                values[name] = series[i] * (1 - t) + series[i + 1] * t
            best = (distance, values)
    return best


def summarize(values):
    errors = [abs(a - b) for a, b in values]
    return (statistics.mean(errors), max(errors),
            statistics.mean(a for a, _ in values),
            statistics.mean(b for _, b in values))


def angle_error(a, b):
    return abs((a - b + math.pi) % (2 * math.pi) - math.pi)


def center_direction_error(segments, path_time, source_angle):
    if not segments:
        return None
    ordered = [segments[i] for i in sorted(segments)]
    i = max(0, min(len(ordered) - 1, int(math.floor(path_time))))
    t = max(0.0, min(1.0, path_time - i))
    p0, p1, p2, p3 = ordered[i]
    dx = (3 * (1 - t) ** 2 * (p1[0] - p0[0])
          + 6 * (1 - t) * t * (p2[0] - p1[0])
          + 3 * t * t * (p3[0] - p2[0]))
    dy = (3 * (1 - t) ** 2 * (p1[1] - p0[1])
          + 6 * (1 - t) * t * (p2[1] - p1[1])
          + 3 * t * t * (p3[1] - p2[1]))
    return angle_error(source_angle, math.atan2(dy, dx))


def y_flipped_lightness(normal, slope, u):
    radial_z = math.sqrt(max(0.0, 1 - u * u))
    tangent = (normal[1], normal[0])
    norm = math.sqrt(1 + slope * slope)
    nx = (u * normal[0] - slope * tangent[0]) / norm
    ny = (u * normal[1] - slope * tangent[1]) / norm
    nz = radial_z / norm
    lam = max(0.0, min(1.0,
        nx * -0.353553 + ny * 0.382683 + nz * 0.853553))
    return 1 - lam


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("typst_trace", type=Path)
    args = parser.parse_args()
    source, shadows = source_samples(args.source_log)
    typst = {}
    for trace in json.loads(args.typst_trace.read_text()):
        for lane in trace["inner-lanes"]:
            typst[(trace["strand"], trace["segment"], lane["lane"])] = lane

    for key, pair in PAIRS.items():
        lane = typst[pair]
        points = [tuple(map(float, p)) for p in lane["points"]]
        current_light = list(map(float, lane["lightness"]))
        candidate_light = [y_flipped_lightness(normal, slope, lane["u"])
                           for normal, slope in zip(lane["normals"], lane["radius-slopes"])]
        candidate_shadow_width = []
        fields = {
            "width": list(map(float, lane["widths"])),
            "lightness": current_light,
            "candidate_light": candidate_light,
            "normal_x": [normal[0] for normal in lane["normals"]],
            "normal_y": [normal[1] for normal in lane["normals"]],
            "radius_slope": list(map(float, lane["radius-slopes"])),
        }
        paired = []
        shadow_count = 0
        for row in source.get(key, []):
            if row["width"] is None:
                continue
            distance, values = nearest_sample(row["point"], points, fields)
            is_shadow = any(math.dist(row["point"], shadow) < 1e-7
                            for shadow in shadows.get(key, []))
            if is_shadow:
                shadow_count += 1
                candidate_light = 1.0
            else:
                candidate_light = values["candidate_light"]
            current = values["lightness"]
            candidate_width = (values["width"] * candidate_light / current
                               if current > 1e-9 else values["width"])
            candidate_shadow_width.append((row["effective-width"], candidate_width))
            values["is_shadow"] = is_shadow
            paired.append((distance, row, values))
        if not paired:
            print(f"source={key} typst={pair}: no paired width/light samples")
            continue
        width_errors = [(row["effective-width"], values["width"])
                        for _, row, values in paired]
        light_errors = [(row["lightness"], values["lightness"])
                        for _, row, values in paired]
        angle_errors = [(
            angle_error(row["angles"][0], math.asin(max(-1.0, min(1.0, lane["u"])))))
            for _, row, _ in paired
        ]
        direction_errors = [(
            angle_error(row["angles"][1], math.atan2(-values["normal_x"], values["normal_y"])))
            for _, row, values in paired
        ]
        width_slope_errors = [
            angle_error(row["angles"][2], math.atan(values["radius_slope"]))
            for _, row, values in paired
        ]
        center_errors = [row["center-direction-error"] for _, row, _ in paired
                         if row["center-direction-error"] is not None]
        mean_distance = statistics.mean(d for d, _, _ in paired)
        max_distance = max(d for d, _, _ in paired)
        wmae, wmax, ws, wt = summarize(width_errors)
        cmae, cmax, _, wc = summarize(candidate_shadow_width)
        lmae, lmax, ls, lt = summarize(light_errors)
        print(
            f"source={key} typst={pair} samples={len(paired)} "
            f"distance={mean_distance:.6g}/{max_distance:.6g}mm "
            f"width={ws:.5f}/{wt:.5f}mm mae/max={wmae:.5f}/{wmax:.5f} "
            f"yflip+shadow={wc:.5f} mae/max={cmae:.5f}/{cmax:.5f} "
            f"shadow-samples={shadow_count} "
            f"light={ls:.4f}/{lt:.4f} mae/max={lmae:.4f}/{lmax:.4f} "
            f"angle-at-geometric-pairing-mae/max-deg[cross,center,width]="
            f"{math.degrees(statistics.mean(angle_errors)):.4f}/{math.degrees(max(angle_errors)):.4f},"
            f"{math.degrees(statistics.mean(direction_errors)):.4f}/{math.degrees(max(direction_errors)):.4f},"
            f"{math.degrees(statistics.mean(width_slope_errors)):.4f}/{math.degrees(max(width_slope_errors)):.4f} "
            f"source-green-vs-uncut-centerline-at-callback-time-mae/max-deg="
            f"{math.degrees(statistics.mean(center_errors)):.4f}/{math.degrees(max(center_errors)):.4f}"
        )


if __name__ == "__main__":
    main()
