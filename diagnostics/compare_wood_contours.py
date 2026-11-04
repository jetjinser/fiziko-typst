#!/usr/bin/env python3
"""Pair one pinned-source cLine trace with its Typst contour metadata."""

import argparse
import itertools
import json
import math
import re
from pathlib import Path


def read_source(path: Path, height: int):
    level = None
    points = []
    cells = []
    brush_nodes = []
    brush_leaves = []
    thin_nodes = []
    thin_dashes = []
    thin_calls = []
    thin_q_widths = {}
    thin_fixed_widths = {}
    lines = path.read_text().splitlines()
    for line in lines:
        match = re.match(r"CLLEVEL\s+(-?[\d.]+)", line)
        if match and level is None:
            level = float(match.group(1))
    for line in lines:
        match = re.match(r"CLPATH\s+\d+\s+(-?[\d.]+)\s+(-?[\d.]+)", line)
        if match:
            i, j = map(float, match.groups())
            points.append((j, height - i))
            continue
        match = re.match(
            r"CLSTEP\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+([\d.]+)", line
        )
        if match:
            i, j, step = map(int, match.groups()[:3])
            extent = float(match.group(4))
            if step >= 0 and i >= 0:
                cells.append(((j, height - 1 - i), extent))
        if line.startswith("WBNODE "):
            fields = line.split()
            if len(fields) >= 6:
                brush_nodes.append({
                    "depth": int(fields[1]),
                    "width-a": float(fields[2]),
                    "width-b": float(fields[3]),
                    "cut-time": float(fields[4]),
                    "length": float(fields[5]),
                    "cut-point": None,
                })
        if line.startswith("WBCUT ") and brush_nodes:
            fields = line.split()
            if len(fields) == 4:
                brush_nodes[-1]["cut-point"] = (
                    float(fields[3]), height - float(fields[2])
                )
        if line.startswith("WBTHIN "):
            fields = line.split()
            if len(fields) >= 11:
                thin_nodes.append({
                    "call-id": int(fields[1]),
                    "depth": int(fields[2]),
                    "branch": fields[3],
                    "width-a": float(fields[4]),
                    "width-b": float(fields[5]),
                    "w2": float(fields[6]),
                    "cut-time": float(fields[7]),
                    "length": float(fields[8]),
                    "left-length": float(fields[9]),
                    "right-length": float(fields[10]),
                    "cut-point": None,
                    "path-start": None,
                    "path-end": None,
                })
        if line.startswith("WBTCALL "):
            fields = line.split()
            if len(fields) == 10:
                thin_calls.append({
                    "call-id": int(fields[1]),
                    "depth": int(fields[2]),
                    "width-a": float(fields[3]),
                    "width-b": float(fields[4]),
                    "length": float(fields[5]),
                    "path-start": (float(fields[7]), height - float(fields[6])),
                    "path-end": (float(fields[9]), height - float(fields[8])),
                })
        if line.startswith("WBQCTRL "):
            fields = line.split()
            if len(fields) == 20:
                call_id = int(fields[1])
                values = list(map(int, fields[4:]))
                y_values = [values[i + 2] * 256 + values[i + 3]
                            for i in range(0, len(values), 4)]
                thin_q_widths.setdefault(call_id, []).extend(y_values)
        if line.startswith("WBTFIX "):
            fields = line.split()
            if len(fields) == 13:
                call_id = int(fields[1])
                values = list(map(int, fields[3:]))
                thin_fixed_widths[call_id] = {
                    "w0": values[0] * 256 + values[1],
                    "w1": values[2] * 256 + values[3],
                    "w2": values[4] * 256 + values[5],
                    "min-width": values[6] * 256 + values[7],
                    "dash-step": values[8] * 256 + values[9],
                }
        if line.startswith("WBTHINPATH ") and thin_nodes:
            fields = line.split()
            if len(fields) == 6:
                # Source wood coordinates (u, v) map to panel coordinates (v, h-u).
                thin_nodes[-1]["path-start"] = (
                    float(fields[3]), height - float(fields[2])
                )
                thin_nodes[-1]["path-end"] = (
                    float(fields[5]), height - float(fields[4])
                )
        if line.startswith("WBTHINCUT ") and thin_nodes:
            fields = line.split()
            if len(fields) == 4:
                thin_nodes[-1]["cut-point"] = (
                    float(fields[3]), height - float(fields[2])
                )
        if line.startswith("WBTHINDASH "):
            fields = line.split()
            if len(fields) == 9:
                thin_dashes.append({
                    "call-id": int(fields[1]),
                    "depth": int(fields[2]),
                    "width": float(fields[3]),
                    "length": float(fields[4]),
                    "path-start": (float(fields[6]), height - float(fields[5])),
                    "path-end": (float(fields[8]), height - float(fields[7])),
                })
        if line.startswith("WBLEAF "):
            fields = line.split()
            brush_leaves.append(fields[1])
    for call in thin_calls:
        call_id = call["call-id"]
        q_widths = thin_q_widths.get(call_id, ())
        call["q-width-range-fixed"] = (
            (min(q_widths), max(q_widths)) if q_widths else None
        )
        call["fixed-widths"] = thin_fixed_widths.get(call_id)
    if level is None or not points or not cells:
        raise ValueError("source log is missing its first CLLEVEL, CLPATH, or CLSTEP")
    return (level, points, cells, brush_nodes, brush_leaves, thin_nodes,
            thin_dashes, thin_calls)


def point_segment_distance(point, start, end):
    dx = end[0] - start[0]
    dy = end[1] - start[1]
    norm = dx * dx + dy * dy
    t = 0 if norm == 0 else max(
        0, min(1, ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / norm)
    )
    return math.dist(point, (start[0] + t * dx, start[1] + t * dy))


def path_distance(point, polyline):
    return min(
        point_segment_distance(point, a, b)
        for a, b in zip(polyline, polyline[1:])
    )


def edit_distance(a, b):
    row = list(range(len(b) + 1))
    for i, value in enumerate(a, 1):
        next_row = [i]
        for j, other in enumerate(b, 1):
            next_row.append(min(
                next_row[-1] + 1,
                row[j] + 1,
                row[j - 1] + (value != other),
            ))
        row = next_row
    return row[-1]


def make_forest(nodes):
    roots = []
    stack = []
    for node in nodes:
        node["children"] = []
        while stack and stack[-1]["depth"] >= node["depth"]:
            stack.pop()
        if stack:
            stack[-1]["children"].append(node)
        else:
            roots.append(node)
        stack.append(node)
    return roots


def endpoint_error(a, b):
    direct = (math.dist(a["path-start"], b["path-start"])
              + math.dist(a["path-end"], b["path-end"])) / 2
    reverse = (math.dist(a["path-start"], b["path-end"])
               + math.dist(a["path-end"], b["path-start"])) / 2
    return min(direct, reverse)


def pair_thin_trees(source_calls, source_nodes, source_dashes, typst_nodes):
    decisions = {node["call-id"]: node for node in source_nodes}
    dash_ids = {node["call-id"] for node in source_dashes}
    source_forest = make_forest(source_calls)
    typst_thin = [
        node.copy() for node in typst_nodes if node["stage"] == "thin"
    ]
    for index, node in enumerate(typst_thin):
        node["trace-index"] = index
    typst_forest = make_forest(typst_thin)
    for node in source_calls:
        event = decisions.get(node["call-id"])
        node["recurse"] = event is not None and event["branch"] == "R"
        node["dash"] = node["call-id"] in dash_ids
    pairs = []
    divergences = []
    root_candidates = sorted(
        (endpoint_error(source, typst), si, ti)
        for si, source in enumerate(source_forest)
        for ti, typst in enumerate(typst_forest)
    )
    used_source = set()
    used_typst = set()
    root_pairs = []
    for error, si, ti in root_candidates:
        if si in used_source or ti in used_typst:
            continue
        used_source.add(si)
        used_typst.add(ti)
        root_pairs.append((error, source_forest[si], typst_forest[ti]))

    def walk(source, typst):
        error = endpoint_error(source, typst)
        pairs.append((error, source, typst))
        source_recurse = source["recurse"]
        typst_recurse = typst["recurse"]
        if source_recurse != typst_recurse:
            typst_q_widths = [point[1]
                              for curve in typst.get("q-curves-fixed") or ()
                              for point in curve]
            divergences.append({
                "source-id": source["call-id"],
                "source-depth": source["depth"],
                "source-recurse": source_recurse,
                "source-dash": source["dash"],
                "source-widths": (source["width-a"], source["width-b"]),
                "source-w2": decisions.get(source["call-id"], {}).get("w2"),
                "source-fixed-widths": source.get("fixed-widths"),
                "source-q-width-range-fixed": source.get("q-width-range-fixed"),
                "source-length-mm": source["length"],
                "typst-index": typst.get("trace-index"),
                "typst-depth": typst["depth"],
                "typst-recurse": typst_recurse,
                "typst-dash": typst["dash"],
                "typst-width-range": (typst["width-min"], typst["width-max"]),
                "typst-q-width-range-fixed": (
                    (min(typst_q_widths), max(typst_q_widths))
                    if typst_q_widths else None
                ),
                "typst-target": typst["target"],
                "typst-length-mm": typst["length"],
                "endpoint-error-mm": error,
                "source-child-count": len(source["children"]),
                "typst-child-count": len(typst["children"]),
            })
            return
        if source_recurse:
            if len(source["children"]) != len(typst["children"]):
                divergences.append({
                    "source-id": source["call-id"],
                    "source-depth": source["depth"],
                    "source-recurse": True,
                    "source-widths": (source["width-a"], source["width-b"]),
                    "source-w2": decisions.get(source["call-id"], {}).get("w2"),
                    "source-length-mm": source["length"],
                    "typst-index": typst.get("trace-index"),
                    "typst-depth": typst["depth"],
                    "typst-recurse": True,
                    "typst-width-range": (typst["width-min"], typst["width-max"]),
                    "typst-target": typst["target"],
                    "typst-length-mm": typst["length"],
                    "endpoint-error-mm": error,
                    "source-child-count": len(source["children"]),
                    "typst-child-count": len(typst["children"]),
                })
            count = min(len(source["children"]), len(typst["children"]))
            source_children = source["children"][:count]
            target_children = typst["children"][:count]
            assignment = min(
                itertools.permutations(target_children),
                key=lambda order: sum(
                    endpoint_error(source_child, typst_child)
                    for source_child, typst_child in zip(source_children, order)
                ),
            )
            for source_child, typst_child in zip(source_children, assignment):
                walk(source_child, typst_child)

    root_report = []
    for error, source, typst in root_pairs:
        root_report.append({
            "source-id": source["call-id"],
            "typst-index": typst.get("trace-index"),
            "endpoint-error-mm": error,
        })
        walk(source, typst)
    return {
        "source-root-count": len(source_forest),
        "typst-root-count": len(typst_forest),
        "root-pairs": root_report,
        "tree-node-pairs": len(pairs),
        "pairs-within-0.1mm": sum(error <= 0.1 for error, _, _ in pairs),
        "paired-decision-count": len(pairs),
        "decision-agreements": sum(
            source["recurse"] == typst["recurse"]
            for _, source, typst in pairs
        ),
        "divergences": divergences[:12],
    }


def pair_thin_nodes(source_nodes, typst_nodes):
    source_nodes = [node for node in source_nodes
                    if node["path-start"] is not None and node["path-end"] is not None]
    typst_nodes = [node for node in typst_nodes if node["stage"] == "thin"]
    candidates = []
    for si, source in enumerate(source_nodes):
        for ti, typst in enumerate(typst_nodes):
            direct = (math.dist(source["path-start"], typst["path-start"])
                      + math.dist(source["path-end"], typst["path-end"])) / 2
            reverse = (math.dist(source["path-start"], typst["path-end"])
                       + math.dist(source["path-end"], typst["path-start"])) / 2
            candidates.append((min(direct, reverse), si, ti))
    candidates.sort()
    used_source = set()
    used_typst = set()
    pairs = []
    for endpoint_error, si, ti in candidates:
        if si in used_source or ti in used_typst:
            continue
        used_source.add(si)
        used_typst.add(ti)
        pairs.append((endpoint_error, source_nodes[si], typst_nodes[ti]))
    close = [pair for pair in pairs if pair[0] <= 0.1]
    cut_errors = [math.dist(source["cut-point"], typst["cut-point"])
                  for _, source, typst in close
                  if source["cut-point"] is not None and typst["cut-point"] is not None]
    branch_pairs = [pair for pair in close if pair[1]["branch"] in ("R", "L")]
    return {
        "source-thin-nodes-with-geometry": len(source_nodes),
        "typst-thin-nodes": len(typst_nodes),
        "unique-endpoint-pairs-within-0.1mm": len(close),
        "paired-outer-decision-count": len(branch_pairs),
        "outer-decisions-agree-with-recurse": sum(
            (source["branch"] == "R") == typst["recurse"]
            for _, source, typst in branch_pairs
        ),
        "paired-cut-point-count": len(cut_errors),
        "paired-cut-point-mae-mm": (
            sum(cut_errors) / len(cut_errors) if cut_errors else None
        ),
        "paired-cut-point-max-mm": max(cut_errors) if cut_errors else None,
        "closest-pairs": [
            {
                "endpoint-error-mm": endpoint_error,
                "source-depth": source["depth"],
                "source-branch": source["branch"],
                "typst-depth": typst["depth"],
                "typst-recurse": typst["recurse"],
                "source-cut": source["cut-point"],
                "typst-cut": typst["cut-point"],
            }
            for endpoint_error, source, typst in pairs[:8]
        ],
    }


def pair_dash_leaves(source_dashes, typst_nodes):
    typst_dashes = [node for node in typst_nodes if node["stage"] == "thin" and node["dash"]]
    candidates = []
    for si, source in enumerate(source_dashes):
        for ti, typst in enumerate(typst_dashes):
            direct = (math.dist(source["path-start"], typst["path-start"])
                      + math.dist(source["path-end"], typst["path-end"])) / 2
            reverse = (math.dist(source["path-start"], typst["path-end"])
                       + math.dist(source["path-end"], typst["path-start"])) / 2
            candidates.append((min(direct, reverse), si, ti))
    candidates.sort()
    used_source = set()
    used_typst = set()
    pairs = []
    for endpoint_error, si, ti in candidates:
        if si in used_source or ti in used_typst:
            continue
        used_source.add(si)
        used_typst.add(ti)
        pairs.append((endpoint_error, source_dashes[si], typst_dashes[ti]))
    source_leaf_nearest = []
    for si, source in enumerate(source_dashes):
        nearest = min((pair for pair in candidates if pair[1] == si),
                      key=lambda pair: pair[0])
        typst = typst_dashes[nearest[2]]
        source_leaf_nearest.append({
            "source-depth": source["depth"],
            "source-length-mm": source["length"],
            "source-start": source["path-start"],
            "source-end": source["path-end"],
            "nearest-typst": {
                "endpoint-error-mm": nearest[0],
                "depth": typst["depth"],
                "dash": typst["dash"],
                "start": typst["path-start"],
                "end": typst["path-end"],
            },
        })
    return {
        "source-dashes": len(source_dashes),
        "typst-dashes": len(typst_dashes),
        "pairs-within-0.1mm": sum(pair[0] <= 0.1 for pair in pairs),
        "endpoint-distance-mae-mm": (
            sum(pair[0] for pair in pairs) / len(pairs) if pairs else None
        ),
        "nearest-pairs": [
            {
                "endpoint-error-mm": endpoint_error,
                "source-depth": source["depth"],
                "source-length-mm": source["length"],
                "typst-depth": typst["depth"],
                "typst-length-mm": typst["length"],
            }
            for endpoint_error, source, typst in pairs[:8]
        ],
        "source-leaf-nearest": source_leaf_nearest,
    }


def summarize(source_log: Path, typst_json: Path, height: int, field_scale: float,
              q_replay: bool = False):
    (source_level, source_points, source_cells, source_nodes, source_leaves,
     source_thin_nodes, source_thin_dashes, source_thin_calls) = read_source(
        source_log, height
    )
    trace = json.loads(typst_json.read_text())
    target_level = -source_level * field_scale
    level_index = min(
        range(len(trace["levels"])),
        key=lambda i: abs(trace["levels"][i] - target_level),
    )
    expected_cells = [cell for cell, _ in reversed(source_cells)]
    source_ranges = [extent for _, extent in reversed(source_cells)]
    candidates = [p for p in trace["paths"] if p["level-index"] == level_index]
    if not candidates:
        raise ValueError(f"Typst has no paths at nearest level {level_index}")

    ranked = []
    for path in candidates:
        actual_cells = [tuple(cell) for cell in path["cells"]]
        errors = [path_distance(point, path["points"]) for point in source_points]
        range_errors = [
            abs(a - b) for a, b in zip(source_ranges, path["cell-ranges"])
        ]
        ranked.append((edit_distance(expected_cells, actual_cells),
                       sum(errors) / len(errors), path, errors, range_errors))
    edits, _, path, distances, range_errors = min(ranked, key=lambda item: item[:2])
    summary = {
        "source-level": source_level,
        "typst-level-target": target_level,
        "typst-level-index": level_index,
        "typst-level": trace["levels"][level_index],
        "path-index": path["path-index"],
        "cell-edit-distance": edits,
        "cell-counts": [len(expected_cells), len(path["cells"])],
        "mean-source-point-distance-mm": sum(distances) / len(distances),
        "max-source-point-distance-mm": max(distances),
        "paired-cell-range-count": min(len(source_ranges), len(path["cell-ranges"])),
        "cell-range-mae": (
            sum(range_errors) / len(range_errors) if range_errors else None
        ),
        "cell-range-max-error": max(range_errors) if range_errors else None,
    }
    trace_prefix = "q-" if q_replay else "brush-"
    trace_nodes_key = trace_prefix + "nodes"
    if source_nodes and trace_nodes_key in trace:
        source_root = source_nodes[0]
        typst_nodes = trace[trace_nodes_key]
        typst_root = next((node for node in typst_nodes
                           if node["stage"] == "outer" and node["depth"] == 0), None)
        summary.update({
            "source-brush-outer-nodes": len(source_nodes),
            "source-brush-max-depth": max(node["depth"] for node in source_nodes),
            "source-brush-leaves": {
                kind.lower(): source_leaves.count(kind)
                for kind in sorted(set(source_leaves))
            },
            "typst-brush-nodes": {
                stage: sum(node["stage"] == stage for node in typst_nodes)
                for stage in sorted({node["stage"] for node in typst_nodes})
            },
            "typst-brush-max-depth": max(node["depth"] for node in typst_nodes),
            "source-thin-brush-nodes": len(source_thin_nodes),
            "source-thin-brush-calls": len(source_thin_calls),
            "source-thin-brush-max-depth": (
                max(node["depth"] for node in source_thin_nodes)
                if source_thin_nodes else None
            ),
            "source-thin-brush-recursive-nodes": sum(
                node["branch"] == "R" for node in source_thin_nodes
            ),
            "source-thin-brush-dash-leaves": len(source_thin_dashes),
            "source-typst-dash-pairing": pair_dash_leaves(
                source_thin_dashes, typst_nodes
            ),
            "source-thin-brush-recursion-pairs": pair_thin_nodes(
                source_thin_nodes, typst_nodes
            ),
            "source-typst-thin-tree-pairing": pair_thin_trees(
                source_thin_calls, source_thin_nodes, source_thin_dashes,
                typst_nodes,
            ),
            "typst-thin-brush-dash-leaves": trace.get(trace_prefix + "dashes"),
            "typst-brush-rng-calls": trace.get(trace_prefix + "rng-calls"),
        })
        if typst_root and typst_root["cut-point"] is not None:
            summary["root-cut-distance-mm"] = math.dist(
                source_root["cut-point"], typst_root["cut-point"]
            )
            summary["root-lengths-mm"] = [
                source_root["length"], typst_root["length"]
            ]
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("typst_json", type=Path)
    parser.add_argument("--height", type=int, default=33,
                        help="woodBlock internal width (default: 33 mm)")
    parser.add_argument("--field-scale", type=float, default=24,
                        help="Typst field scale relative to source (default: 24)")
    parser.add_argument("--q-replay", action="store_true",
                        help="pair against the opt-in source q-template replay")
    args = parser.parse_args()
    print(json.dumps(summarize(args.source_log, args.typst_json,
                               args.height, args.field_scale,
                               q_replay=args.q_replay), indent=2))


if __name__ == "__main__":
    main()
