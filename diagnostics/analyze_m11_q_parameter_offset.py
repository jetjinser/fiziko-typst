#!/usr/bin/env python3
"""Compare source and Typst q-x position/slope at near-endpoint cuts.

Usage: analyze_m11_q_parameter_offset.py MPOST_LOG TYPOGRAPHY_REPLAY_JSON

Pairs recursive nodes by call/lane and center-path endpoints, then evaluates
the source and generated q cubics at the source's 16.16 cut parameter.
"""

import argparse
import json
import math
from pathlib import Path

SCALE = 1 << 16
MM_PER_BP = 25.4 / 72


def fixed(hi: str, lo: str) -> int:
    return int(hi) * 256 + int(lo)


def parse_source(path: Path) -> list[dict]:
    nodes = []
    current = None
    for line in path.read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        if fields[0] == "M11QPT":
            call, lane, depth, segment, control = map(int, fields[1:6])
            if segment == 0 and control == 0:
                current = {
                    "call": call, "lane": lane, "depth": depth,
                    "curves": [], "path_start": None, "path_end": None,
                    "target": None, "cut": None,
                }
                nodes.append(current)
            if current is None or current["depth"] != depth:
                raise ValueError(f"orphan q control: {line}")
            if segment == len(current["curves"]):
                current["curves"].append([])
            if segment != len(current["curves"]) - 1:
                raise ValueError(f"out-of-order q segment: {line}")
            if control != len(current["curves"][segment]):
                raise ValueError(f"out-of-order q control: {line}")
            current["curves"][segment].append((
                fixed(fields[6], fields[7]), fixed(fields[8], fields[9])))
        elif current is not None and fields[0] == "M11THINPATH":
            if (int(fields[1]), int(fields[2])) == (current["call"], current["lane"]):
                current["path_start"] = (float(fields[4]), float(fields[5]))
                current["path_end"] = (float(fields[6]), float(fields[7]))
        elif current is not None and fields[0] == "M11TCUT":
            if (int(fields[1]), int(fields[2])) == (current["call"], current["lane"]):
                current["target"] = float(fields[4])
        elif current is not None and fields[0] == "M11TCUTFIX":
            if (int(fields[1]), int(fields[2])) == (current["call"], current["lane"]):
                current["cut"] = fixed(fields[4], fields[5])

    return [node for node in nodes if node["path_start"] is not None]


def cubic_value(points, u: float) -> float:
    v = 1 - u
    return (v**3 * points[0] + 3 * v**2 * u * points[1]
            + 3 * v * u**2 * points[2] + u**3 * points[3])


def cubic_derivative(points, u: float) -> float:
    v = 1 - u
    return (3 * v**2 * (points[1] - points[0])
            + 6 * v * u * (points[2] - points[1])
            + 3 * u**2 * (points[3] - points[2]))


def endpoint_error(a, b) -> float:
    return max(math.dist(a["path_start"], b["path-start"]),
               math.dist(a["path_end"], b["path-end"]))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("typst_json", type=Path)
    parser.add_argument("--max-endpoint-error", type=float, default=0.01)
    args = parser.parse_args()

    generated = {}
    for record in json.loads(args.typst_json.read_text()):
        generated[(record["call"], record["lane"])] = record["q-nodes"]

    checked = 0
    for source in parse_source(args.source_log):
        if source["cut"] is None or source["target"] is None:
            continue
        path_time = source["cut"] / SCALE
        segment = int(path_time)
        u = path_time - segment
        if u < 0.9 or segment >= len(source["curves"]):
            continue
        source_curve = source["curves"][segment]
        candidates = generated.get((source["call"], source["lane"]), [])
        if not candidates:
            continue
        candidate = min(candidates, key=lambda node: endpoint_error(source, node))
        error = endpoint_error(source, candidate)
        if error > args.max_endpoint_error:
            continue
        generated_curves = candidate["q-curves-fixed"]
        if segment >= len(generated_curves):
            continue
        generated_curve = generated_curves[segment]
        if len(source_curve) != 4 or len(generated_curve) != 4:
            continue

        source_x = [point[0] for point in source_curve]
        generated_x = [point[0] for point in generated_curve]
        source_y = [point[1] for point in source_curve]
        generated_y = [point[1] for point in generated_curve]
        dx_source = cubic_derivative(source_x, u)
        dx_generated = cubic_derivative(generated_x, u)
        x_delta = cubic_value(generated_x, u) - cubic_value(source_x, u)
        y_delta = cubic_value(generated_y, u) - cubic_value(source_y, u)
        dy_delta = cubic_derivative(generated_y, u) - cubic_derivative(source_y, u)
        print(
            f"{source['call']}/{source['lane']} depth={source['depth']} "
            f"t={path_time:.5f} u={u:.5f} endpoint-error={error:.6f}mm "
            f"dx={x_delta:+.2f} fixed ({x_delta * MM_PER_BP / SCALE:+.6f}mm) "
            f"d(dx/du)={dx_generated - dx_source:+.2f} fixed "
            f"y={y_delta:+.2f} fixed dy={dy_delta:+.2f} fixed"
        )
        checked += 1

    print(f"paired near-endpoint cuts: {checked}")


if __name__ == "__main__":
    main()
