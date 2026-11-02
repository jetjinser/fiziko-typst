#!/usr/bin/env python3
"""Pair one pinned-source cLine trace with its Typst contour metadata."""

import argparse
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
            if len(fields) >= 10:
                thin_nodes.append({
                    "depth": int(fields[1]),
                    "branch": fields[2],
                    "width-a": float(fields[3]),
                    "width-b": float(fields[4]),
                    "target": float(fields[5]),
                    "cut-time": float(fields[6]),
                    "length": float(fields[7]),
                    "left-length": float(fields[8]),
                    "right-length": float(fields[9]),
                    "cut-point": None,
                    "path-start": None,
                    "path-end": None,
                })
        if line.startswith("WBTCALL "):
            fields = line.split()
            if len(fields) == 5:
                thin_calls.append({
                    "depth": int(fields[1]),
                    "width-a": float(fields[2]),
                    "width-b": float(fields[3]),
                    "length": float(fields[4]),
                })
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
            if len(fields) == 8:
                thin_dashes.append({
                    "depth": int(fields[1]),
                    "width": float(fields[2]),
                    "length": float(fields[3]),
                    "path-start": (float(fields[5]), height - float(fields[4])),
                    "path-end": (float(fields[7]), height - float(fields[6])),
                })
        if line.startswith("WBLEAF "):
            fields = line.split()
            brush_leaves.append(fields[1])
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


def summarize(source_log: Path, typst_json: Path, height: int, field_scale: float):
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
    if source_nodes and "brush-nodes" in trace:
        source_root = source_nodes[0]
        typst_nodes = trace["brush-nodes"]
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
            "typst-thin-brush-dash-leaves": trace.get("brush-dashes"),
            "typst-brush-rng-calls": trace.get("brush-rng-calls"),
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
    args = parser.parse_args()
    print(json.dumps(summarize(args.source_log, args.typst_json,
                               args.height, args.field_scale), indent=2))


if __name__ == "__main__":
    main()
