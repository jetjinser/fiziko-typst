#!/usr/bin/env python3
"""Replay Fiziko's midpoint selection from an instrumented S104 thin-brush log.

Usage: replay_s104_thin_intersections.py MPOST_LOG ROW [--node ID]

MetaPost's built-in ``intersectiontimes`` results are recorded as ``S104-FIRST``.
This script applies Fiziko's forward/reverse preference and cutPathTime's
midpoint-nearest choice to those raw results. It also compares a fixed-point
packet-search model of MetaPost's low-level cubic intersection routine with
the logged raw results. It reproduces all recorded raw pairs across the fresh
62-row S104 trace and the minimized M11 coast endpoint sweep; it remains a
diagnostic implementation, not yet wired into production brush sampling.
"""

import argparse
from collections import defaultdict
from pathlib import Path


# MetaPost's cubic_intersection adds two bits after the nominal 17-level
# parameter search. The source-state replay below models the packed max_t
# threshold, branch-dependent tolerance, saved approximation, and backtrack
# limit. The depth is retained as a parameter because its precise relationship
# to the source packet-stack capacity is not needed for observed intersections.
MAX_INTERSECTION_DEPTH = 19


def load(log_path: str, row: float):
    nodes = defaultdict(lambda: {
        "first": [], "first-fixed": [], "controls": defaultdict(dict), "thin": None,
        "rays": defaultdict(dict), "y_controls": defaultdict(dict),
        "hit": None, "hit_x": None, "hit-fixed": None,
    })
    for line in Path(log_path).read_text().splitlines():
        p = line.split()
        if len(p) < 3 or p[0] not in {
            "S104-FIRST", "S104-FIRST-FIX", "S104-TXCTRL", "S104-TCTRL",
            "S104-TRAY", "S104-THIN",
            "S104-THIN-HIT-T", "S104-THIN-HIT-X", "S104-THIN-HIT-FIX",
            "S104-THIN-TIMES-FIX", "S104-THIN-POS-FIX",
        }:
            continue
        if abs(float(p[1]) - row) > 0.00001:
            continue
        node = nodes[int(p[2])]
        if p[0] == "S104-FIRST":
            node["first"].append(tuple(map(float, p[3:7])))
        elif p[0] == "S104-FIRST-FIX":
            chunks = [int(value) for value in p[3:11]]
            node["first-fixed"].append(tuple(
                (chunks[i] * 256 + chunks[i + 1]) / 65536
                for i in (0, 2, 4, 6)
            ))
        elif p[0] == "S104-TXCTRL":
            segment, control = int(p[4]), int(p[5])
            node["controls"][segment][control] = int(p[6]) * 256 + int(p[7])
        elif p[0] == "S104-TCTRL":
            segment, control = int(p[4]), int(p[5])
            node["y_controls"][segment][control] = int(p[8]) * 256 + int(p[9])
        elif p[0] == "S104-TRAY":
            ray, control = int(p[3]), int(p[4])
            node["rays"][ray][control] = (
                int(p[5]) * 256 + int(p[6]),
                int(p[7]) * 256 + int(p[8]),
            )
        elif p[0] == "S104-THIN":
            node["thin"] = {
                "depth": int(p[3]), "time": float(p[9]),
                "length": float(p[10]),
            }
        elif p[0] == "S104-THIN-HIT-T":
            node["hit"] = tuple(map(float, p[3:7]))
        elif p[0] == "S104-THIN-HIT-X":
            node["hit_x"] = tuple(map(float, p[3:5]))
        elif p[0] == "S104-THIN-HIT-FIX":
            node["hit-fixed"] = {
                "levels": tuple(decode_pair(p[i], p[i + 1]) for i in (3, 5))
            }
        elif p[0] == "S104-THIN-TIMES-FIX":
            node.setdefault("hit-fixed", {})["times"] = tuple(
                decode_pair(p[i], p[i + 1]) for i in (3, 5))
        elif p[0] == "S104-THIN-POS-FIX":
            node.setdefault("hit-fixed", {})["positions"] = tuple(
                decode_pair(p[i], p[i + 1]) for i in (3, 5))
    return nodes


def decode_pair(high: str, low: str) -> float:
    return (int(high) * 256 + int(low)) / 65536


def source_first_intersection(raw, path_length):
    """Apply the pinned firstIntersectionTimes macro to its raw pair."""
    x1, y1, x2, y2 = raw
    if x1 < x2:
        result = x1, y1
    else:
        result = x2, path_length - y2
    if x1 < 0:
        result = x2, y2
    return result


def replay(node):
    pairs = node["first-fixed"] or node["first"]
    first, second = pairs[-2:]
    path_length = len(node["controls"])
    cut1 = source_first_intersection(first, path_length)
    cut2 = source_first_intersection(second, path_length)
    if (node["hit-fixed"] is not None
            and all(key in node["hit-fixed"] for key in ("levels", "times", "positions"))):
        _, d3 = node["hit-fixed"]["levels"]
        source_cut1, source_cut2 = node["hit-fixed"]["times"]
        d4, d5 = node["hit-fixed"]["positions"]
    else:
        _, d3, source_cut1, source_cut2 = node["hit"]
        d4, d5 = node["hit_x"]
    chosen = cut1[1] if abs(d4 - d3) < abs(d5 - d3) else cut2[1]
    return {
        "cut1": cut1[1], "cut2": cut2[1], "chosen": chosen,
        "source_cut1": source_cut1, "source_cut2": source_cut2,
        "source_cut": node["thin"]["time"], "d3": d3, "d4": d4,
        "d5": d5,
    }


def half_signed(value: int) -> int:
    """MetaPost's integer half uses Pascal ``div`` (truncation toward zero)."""
    return value // 2 if value >= 0 else -((-value) // 2)


def split_packet(packet):
    """Bisect a cubic's three first-difference packets in scaled integers."""
    left = []
    right = []
    for axis in range(2):
        u1, u2, u3 = (point[axis] for point in packet)
        u2_left = half_signed(u1 + u2)
        u2_right = half_signed(u3 + u2)
        u3_left = half_signed(u2_left + u2_right)
        left.append((u1, u2_left, u3_left))
        right.append((u3_left, u2_right, u3))
    return (
        tuple(tuple(left[axis][k] for axis in range(2)) for k in range(3)),
        tuple(tuple(right[axis][k] for axis in range(2)) for k in range(3)),
    )


def packet_bounds(packet, axis):
    values = [0]
    position = 0
    for point in packet:
        position += point[axis]
        values.append(position)
    return min(values), max(values)


def packet_boxes_overlap(left, right, dx, dy, tolerance):
    for axis, delta in ((0, dx), (1, dy)):
        left_min, left_max = packet_bounds(left, axis)
        right_min, right_max = packet_bounds(right, axis)
        if (delta - tolerance > right_max - left_min
                or delta + tolerance < right_min - left_max):
            return False
    return True


def fixed_cubic_intersection(left_points, right_points, tolerance_step):
    """Replay MetaPost's fixed-point packet search for one cubic pair.

    Coordinates are raw 16.16 scaled integers. Child pairs are visited in
    MetaPost's lexicographic order. This also models cubic_intersection's
    global max_t progress threshold and timeout approximation; it remains a
    diagnostic model, not a production solver.
    """
    left = tuple(tuple(left_points[i + 1][axis] - left_points[i][axis]
                       for axis in range(2)) for i in range(3))
    right = tuple(tuple(right_points[i + 1][axis] - right_points[i][axis]
                        for axis in range(2)) for i in range(3))
    start_dx = left_points[0][0] - right_points[0][0]
    start_dy = left_points[0][1] - right_points[0][1]
    backtracks = 0
    max_t = 2
    approximation = None
    stopped = False
    answer = None
    unity = 1 << 16
    max_t_limit = 8 * unity
    low_precision_limit = max_t_limit - unity // 2

    def source_time(encoded):
        # The final MetaPost path-time conversion divides away the two extra
        # bits, then rounds the remaining scaled parameter upward by halves.
        return ((encoded // 4 + 1) // 2) / unity - 1

    def timeout_answer():
        if approximation is None:
            return None
        t, tt = (value // 4 for value in approximation)
        while t < unity:
            t *= 2
            tt *= 2
        return t / unity - 1, tt / unity - 1

    def descend(a, b, dx, dy, tolerance, three_l, level, ai, bi):
        nonlocal backtracks, max_t, approximation, stopped, answer
        if stopped:
            return answer
        if not packet_boxes_overlap(a, b, dx, dy, tolerance):
            backtracks += 1
            if backtracks > 5000:
                stopped = True
                answer = timeout_answer()
            return None

        cur_t = (1 << level) + ai
        cur_tt = (1 << level) + bi
        if cur_t >= max_t:
            if max_t == max_t_limit or max_t > low_precision_limit:
                answer = (source_time(cur_t), source_time(cur_tt))
                stopped = True
                return answer
            max_t *= 2
            approximation = (cur_t, cur_tt)

        # The pinned scaled build has room for 17 nominal plus two extra
        # bisections. A further descent trips MetaPost's packet-stack guard;
        # the source routes that miss through NOT_FOUND, so this branch fails
        # and the enclosing search continues with its remaining packet pairs.
        if level >= MAX_INTERSECTION_DEPTH:
            backtracks += 1
            if backtracks > 5000:
                stopped = True
                answer = timeout_answer()
                return answer
            return None

        a_left, a_right = split_packet(a)
        b_left, b_right = split_packet(b)
        next_tolerance = 2 * (tolerance - three_l + tolerance_step)
        next_three_l = three_l + tolerance_step
        next_dx, next_dy = 2 * dx, 2 * dy
        for a_side, a_child in enumerate((a_left, a_right)):
            for b_side, b_child in enumerate((b_left, b_right)):
                # NOT_FOUND advances the four child pairs in source order.
                # Every switch to the right packet adds the current three_l
                # to tolerance; the mixed pairs therefore share one increment
                # and the right-right pair has accumulated two.
                branch_tolerance = next_tolerance + next_three_l * (
                    a_side + b_side)
                dx_child = next_dx
                dy_child = next_dy
                if a_side:
                    dx_child += sum(point[0] for point in a_left)
                    dy_child += sum(point[1] for point in a_left)
                if b_side:
                    dx_child -= sum(point[0] for point in b_left)
                    dy_child -= sum(point[1] for point in b_left)
                result = descend(
                    a_child, b_child, dx_child, dy_child,
                    branch_tolerance, next_three_l, level + 1,
                    ai * 2 + a_side, bi * 2 + b_side,
                )
                if result is not None or stopped:
                    return result
        return None

    result = descend(left, right, start_dx, start_dy, 0, 0, 0, 0, 0)
    return answer if stopped else result


def fixed_path_intersection(ray, path):
    """Match MetaPost's path-level lexicographic search and 0/3 retries."""
    for tolerance_step in (0, 3):
        for ray_segment, ray_curve in enumerate((ray,)):
            for path_segment, path_curve in enumerate(path):
                result = fixed_cubic_intersection(
                    ray_curve, path_curve, tolerance_step,
                )
                if result is not None:
                    return ray_segment + result[0], path_segment + result[1]
    return -1.0, -1.0


def fixed_raw_intersections(ray, path):
    direct = fixed_path_intersection(ray, path)
    reverse_path = [tuple(reversed(curve)) for curve in reversed(path)]
    reverse = fixed_path_intersection(ray, reverse_path)
    return direct, reverse


def fixed_intersection_times(ray, path):
    direct, reverse = fixed_raw_intersections(ray, path)
    if direct[0] < reverse[0]:
        return direct
    if direct[0] < 0:
        return reverse
    return reverse[0], len(path) - reverse[1]


def fixed_replay(node):
    path = [
        [
            (node["controls"][segment][control],
             node["y_controls"][segment][control])
            for control in range(4)
        ]
        for segment in sorted(node["controls"])
    ]
    raw_hits = []
    reverse_path = [tuple(reversed(curve)) for curve in reversed(path)]
    for ray_id in (1, 2):
        ray = [node["rays"][ray_id][control] for control in range(4)]
        raw_hits.extend((
            fixed_path_intersection(ray, path),
            fixed_path_intersection(ray, reverse_path),
        ))
    source_raw = node["first-fixed"][-2:] or node["first"][-2:]
    expected_raw = []
    for raw in source_raw:
        expected_raw.append((raw[0], raw[1]))
        expected_raw.append((raw[2], raw[3]))
    return raw_hits, expected_raw


def endpoint_distance(time: float) -> float:
    """Distance to the nearest integer path knot (cubic endpoint)."""
    return abs(time - round(time))


def classify_raw_pair(actual, source):
    actual_hit = actual[0] >= 0 and actual[1] >= 0
    source_hit = source[0] >= 0 and source[1] >= 0
    if actual_hit and not source_hit:
        return "model-only hit"
    if source_hit and not actual_hit:
        near_endpoint = min(endpoint_distance(time) for time in source) <= 1 / 64
        return "missed source hit near cubic endpoint" if near_endpoint else "missed interior source hit"
    if not actual_hit:
        return "matching miss"
    error = max(abs(actual[0] - source[0]), abs(actual[1] - source[1]))
    if error <= 1 / 65536:
        return "matched hit"
    near_endpoint = min(endpoint_distance(time) for time in source) <= 1 / 64
    return "near-endpoint hit differs" if near_endpoint else "interior hit differs"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log")
    parser.add_argument("row", type=float)
    parser.add_argument("--node", type=int)
    parser.add_argument("--verbose", action="store_true",
                        help="print every low-level replay pair, including matches")
    args = parser.parse_args()

    nodes = load(args.log, args.row)
    if args.node is not None:
        nodes = {args.node: nodes[args.node]} if args.node in nodes else {}
    replayed = []
    fixed_results = []
    for serial, node in sorted(nodes.items()):
        if node["thin"] is None:
            continue
        if node["hit"] is None or node["hit_x"] is None or len(node["first"]) < 2:
            continue
        result = replay(node)
        result["serial"] = serial
        result["raw_match"] = max(
            abs(result["cut1"] - result["source_cut1"]),
            abs(result["cut2"] - result["source_cut2"]),
        ) <= 0.00002
        result["cut_match"] = abs(result["chosen"] - result["source_cut"]) <= 0.00002
        replayed.append(result)
        if (len(node["rays"][1]) == 4 and len(node["rays"][2]) == 4
                and len(node["y_controls"]) == len(node["controls"])):
            fixed_hits, source_hits = fixed_replay(node)
            for index, (actual, source) in enumerate(zip(fixed_hits, source_hits)):
                fixed_results.append((serial, index // 2 + 1, index % 2,
                                      actual, source))

    if not replayed:
        raise SystemExit("no complete S104 thin-intersection records for this row")
    print(f"row {args.row:g}: replayed {len(replayed)} source cut decisions")
    print("raw firstIntersectionTimes pairs reproduce cutPathTime:",
          f"{sum(item['raw_match'] for item in replayed)}/{len(replayed)}")
    print("midpoint-nearest selection reproduces source cut:",
          f"{sum(item['cut_match'] for item in replayed)}/{len(replayed)}")
    print("node source-cut1 replay-cut1 source-cut2 replay-cut2 chosen source-cut d3 d4 d5")
    for item in replayed:
        print(f"{item['serial']:4d} {item['source_cut1']:10.6f} "
              f"{item['cut1']:10.6f} {item['source_cut2']:10.6f} "
              f"{item['cut2']:10.6f} {item['chosen']:10.6f} "
              f"{item['source_cut']:10.6f} {item['d3']:10.5f} "
              f"{item['d4']:10.5f} {item['d5']:10.5f}")
    if fixed_results:
        errors = [max(abs(actual[0] - source[0]), abs(actual[1] - source[1]))
                  for _, _, _, actual, source in fixed_results]
        print("fixed packet search vs direct raw hit pairs:",
              f"{sum(error <= 1 / 65536 for error in errors)}/{len(errors)} "
              "within one 16.16 time unit")
        print(f"fixed packet replay mean/max time error: "
              f"{sum(errors) / len(errors):.8g}/{max(errors):.8g}")
        categories = {}
        for _, _, _, actual, source in fixed_results:
            category = classify_raw_pair(actual, source)
            categories[category] = categories.get(category, 0) + 1
        print("raw pair classification:", "; ".join(
            f"{category} {count}" for category, count in sorted(categories.items())
        ))
        for serial, ray_id, reverse, actual, source in fixed_results:
            error = max(abs(actual[0] - source[0]), abs(actual[1] - source[1]))
            if not args.verbose and error <= 1 / 65536:
                continue
            print(f"  node {serial} ray {ray_id} {'reverse' if reverse else 'direct'}: "
                  f"source {source}, replay {actual}")


if __name__ == "__main__":
    main()
