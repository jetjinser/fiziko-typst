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
        if line.startswith("WBLEAF "):
            fields = line.split()
            brush_leaves.append(fields[1])
    if level is None or not points or not cells:
        raise ValueError("source log is missing its first CLLEVEL, CLPATH, or CLSTEP")
    return level, points, cells, brush_nodes, brush_leaves


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


def summarize(source_log: Path, typst_json: Path, height: int, field_scale: float):
    source_level, source_points, source_cells, source_nodes, source_leaves = read_source(
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
