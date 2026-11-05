#!/usr/bin/env python3
"""Pair one source recursive coast width-template node to Typst input knots.

Usage: compare_m11_coast_qknots.py MPOST_LOG TYPST_JSON LANDMASS DEPTH
"""

import json
import math
import sys
from pathlib import Path

PT_TO_MM = 25.4 / 72


def source_knots(log_path, landmass, depth):
    active = False
    current = []
    for line in Path(log_path).read_text().splitlines():
        if line.startswith("M11-COAST-BEGIN "):
            active = int(line.split()[1]) == landmass
            current = []
            continue
        if line.startswith("M11-COAST-END "):
            active = False
            continue
        if not active:
            continue
        fields = line.split()
        if fields[:1] == ["S101-QKNOT"] and len(fields) == 7:
            if int(fields[1]) == depth:
                knot_index = int(fields[2])
                if knot_index == 0:
                    current = []
                current.append((knot_index, *map(float, fields[3:])))
        elif fields[:2] == ["S101", "NODE"] and int(fields[2]) == depth:
            if current:
                return current
            raise SystemExit(f"depth-{depth} source node has no q knots")
    raise SystemExit(f"no depth-{depth} source node for landmass {landmass}")


def typst_arc_at_source_time(entry, source_time):
    times = entry["source-times"]
    arcs = entry["source-arc-positions"]
    if math.isclose(source_time, entry["source-time-end"], abs_tol=1e-9):
        # A closed stroke's final q knot is the start point after traversing
        # the closing arc. Some traces store a duplicate terminal time for the
        # last outline point, so this must take precedence over that sample.
        return arcs[-1]
    time_ends = times[1:] + [entry["source-time-end"]]
    for index, (start, end) in enumerate(zip(times, time_ends)):
        if (start <= source_time <= end) or (end <= source_time <= start):
            fraction = 0.0 if end == start else (source_time - start) / (end - start)
            return arcs[index] * (1 - fraction) + arcs[index + 1] * fraction
    raise ValueError(f"source time {source_time} is outside Typst's path map")


def typst_point_at_source_time(entry, source_time):
    times = entry["source-times"]
    points = entry["outline-points"]
    if math.isclose(source_time, entry["source-time-end"], abs_tol=1e-9):
        return points[0]
    time_ends = times[1:] + [entry["source-time-end"]]
    for index, (start, end) in enumerate(zip(times, time_ends)):
        if (start <= source_time <= end) or (end <= source_time <= start):
            fraction = 0.0 if end == start else (source_time - start) / (end - start)
            next_point = points[index + 1] if index + 1 < len(points) else points[0]
            return tuple(points[index][axis] * (1 - fraction)
                         + next_point[axis] * fraction
                         for axis in range(2))
    raise ValueError(f"source time {source_time} is outside Typst's path map")


def main():
    if len(sys.argv) != 5:
        raise SystemExit(__doc__)
    log, trace_path = sys.argv[1:3]
    landmass, depth = map(int, sys.argv[3:5])
    knots = source_knots(log, landmass, depth)
    trace = json.loads(Path(trace_path).read_text())
    entry = next((item for item in trace if item["landmass"] == landmass), None)
    if entry is None:
        raise SystemExit(f"no Typst trace for landmass {landmass}")
    samples = entry["width-samples"]
    center = (19.0, 22.0)
    pairs = []
    source_points = []
    typst_points = []
    arc_deltas = []
    for index, qx, qy, px, py in knots:
        point = (center[0] + px * PT_TO_MM, center[1] - py * PT_TO_MM)
        source_points.append(point)
        typst_points.append(typst_point_at_source_time(entry, index))
        source_arc = qx * PT_TO_MM
        typst_arc = typst_arc_at_source_time(entry, index)
        arc_deltas.append(source_arc - typst_arc)
        nearest = min(samples, key=lambda sample: math.dist(point, sample["point"]))
        error = math.dist(point, nearest["point"])
        width_error = abs(qy * PT_TO_MM - nearest["width"])
        arc_error = source_arc - nearest["arc"]
        pairs.append((int(index), error, width_error, arc_error))

    chord_arcs = [0.0]
    typst_chord_arcs = [0.0]
    fixed_typst_chord_arcs = [0.0]
    for first, second in zip(source_points, source_points[1:]):
        chord_arcs.append(chord_arcs[-1] + math.dist(first, second))
    for first, second in zip(typst_points, typst_points[1:]):
        typst_chord_arcs.append(typst_chord_arcs[-1] + math.dist(first, second))
    fixed_points = []
    for point in typst_points:
        local_x = (point[0] - center[0]) / PT_TO_MM
        local_y = (center[1] - point[1]) / PT_TO_MM
        fixed_points.append((center[0] + round(local_x * 65536) / 65536 * PT_TO_MM,
                             center[1] - round(local_y * 65536) / 65536 * PT_TO_MM))
    for first, second in zip(fixed_points, fixed_points[1:]):
        fixed_typst_chord_arcs.append(fixed_typst_chord_arcs[-1]
                                      + math.dist(first, second))
    source_minus_chord = [knot[1] * PT_TO_MM - chord
                          for knot, chord in zip(knots, chord_arcs)]
    intervals = []
    for index in range(len(knots) - 1):
        source_increment = (knots[index + 1][1] - knots[index][1]) * PT_TO_MM
        typst_increment = (typst_arc_at_source_time(entry, index + 1)
                           - typst_arc_at_source_time(entry, index))
        intervals.append((index, source_increment, typst_increment,
                          math.dist(source_points[index], source_points[index + 1]),
                          math.dist(typst_points[index], typst_points[index + 1])))
    print("source q.x minus Typst source-arc-at-time mean/max abs: "
          f"{sum(map(abs, arc_deltas)) / len(arc_deltas):.8f}/"
          f"{max(map(abs, arc_deltas)):.8f} mm")
    max_arc_index = max(range(len(arc_deltas)), key=lambda index: abs(arc_deltas[index]))
    print(f"largest indexed q.x/Typst arc delta at source time {max_arc_index}: "
          f"{arc_deltas[max_arc_index]:.8f} mm")
    if max_arc_index < len(source_points):
        print(f"  source/Typst points: {source_points[max_arc_index]}/"
              f"{typst_points[max_arc_index]}; distance "
              f"{math.dist(source_points[max_arc_index], typst_points[max_arc_index]):.8f} mm")
    if 43 < len(arc_deltas):
        print(f"time 43 q.x / Typst arc / delta: "
              f"{knots[43][1] * PT_TO_MM:.8f}/"
              f"{typst_arc_at_source_time(entry, 43):.8f}/"
              f"{arc_deltas[43]:.8f} mm; source q.x minus source-point chord sum: "
              f"{source_minus_chord[43]:.8f} mm; raw/fixed Typst point chord residual: "
              f"{knots[43][1] * PT_TO_MM - typst_chord_arcs[43]:.8f}/"
              f"{knots[43][1] * PT_TO_MM - fixed_typst_chord_arcs[43]:.8f} mm")
    print("largest per-interval source-q.x minus Typst-arc increments:")
    for index, source_inc, typst_inc, source_chord, typst_chord in sorted(
            intervals, key=lambda item: abs(item[1] - item[2]), reverse=True)[:8]:
        print(f"  {index}->{index + 1}: q.x {source_inc:.8f}, "
              f"Typst arc {typst_inc:.8f}, delta {source_inc - typst_inc:.8f}; "
              f"source/Typst chords {source_chord:.8f}/{typst_chord:.8f} mm")
    print("final source-time intervals:")
    for index, source_inc, typst_inc, source_chord, typst_chord in intervals[-8:]:
        print(f"  {index}->{index + 1}: q.x {source_inc:.8f}, "
              f"Typst arc {typst_inc:.8f}, delta {source_inc - typst_inc:.8f}; "
              f"source/Typst chords {source_chord:.8f}/{typst_chord:.8f} mm")

    matched = [item for item in pairs if item[1] <= 0.001]
    print(f"landmass {landmass} depth {depth}: {len(matched)}/{len(pairs)} knots "
          "pair to Typst samples within 0.001 mm")
    if matched:
        print("matched position error mean/max: "
              f"{sum(item[1] for item in matched) / len(matched):.8f}/"
              f"{max(item[1] for item in matched):.8f} mm")
        print("matched width error mean/max: "
              f"{sum(item[2] for item in matched) / len(matched):.8f}/"
              f"{max(item[2] for item in matched):.8f} mm")
        arc_deltas = [item[3] for item in matched]
        arc_mean = sum(arc_deltas) / len(arc_deltas)
        print("matched source-minus-Typst cumulative-arc delta "
              f"mean/min/max: {arc_mean:.8f}/"
              f"{min(arc_deltas):.8f}/{max(arc_deltas):.8f} mm")
        print("matched cumulative-arc deviation from mean (max): "
              f"{max(abs(value - arc_mean) for value in arc_deltas):.8f} mm")
    for index, error, width_error, arc_error in pairs:
        if error > 0.001:
            print(f"unpaired source knot {index}: nearest position error "
                  f"{error:.6f} mm; width difference {width_error:.8f} mm; "
                  f"source-minus-Typst cumulative-arc delta {arc_error:.8f} mm")


if __name__ == "__main__":
    main()
