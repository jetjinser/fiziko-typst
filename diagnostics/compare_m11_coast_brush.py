#!/usr/bin/env python3
"""Pair M11 coast brush recursion nodes with the production Typst trace.

Usage: compare_m11_coast_brush.py MPOST_LOG TYPST_JSON LANDMASS
"""

import itertools
import json
import math
import re
import sys
from pathlib import Path

PT_TO_MM = 25.4 / 72
CENTER = (19.0, 22.0)


def load_source(path, landmass):
    active = False
    nodes = []
    pending_widths = []
    for line in Path(path).read_text().splitlines():
        match = re.fullmatch(r"M11-COAST-BEGIN (\d+)", line)
        if match:
            active = int(match.group(1)) == landmass
            pending_widths = []
            continue
        if line.startswith("M11-COAST-END "):
            active = False
            continue
        if not active:
            continue
        fields = line.split()
        if fields[:1] == ["S101-QKNOT"] and len(fields) >= 5:
            pending_widths.append(float(fields[4]))
        if len(fields) >= 11 and fields[:2] == ["S101", "NODE"]:
            depth, w0, w1, length = map(float, fields[2:6])
            x0, y0, x1, y1 = map(float, fields[7:11])
            convert = lambda p: (CENTER[0] + p[0] * PT_TO_MM,
                                 CENTER[1] - p[1] * PT_TO_MM)
            nodes.append({
                "depth": int(depth),
                "width-min": min(w0, w1) * PT_TO_MM,
                "width-max": max(w0, w1) * PT_TO_MM,
                "width-start": pending_widths[0] * PT_TO_MM,
                "width-end": pending_widths[-1] * PT_TO_MM,
                "length": length * PT_TO_MM,
                "path-start": convert((x0, y0)),
                "path-end": convert((x1, y1)),
                "recurse": None,
                "cut-width": None,
                "cut-time": None,
                "left-length": None,
                "right-length": None,
                "children": [],
            })
            pending_widths = []
        elif fields[:2] == ["S101", "CUT"] and nodes:
            nodes[-1]["cut-width"] = float(fields[3]) * PT_TO_MM
            nodes[-1]["cut-time"] = float(fields[4])
            nodes[-1]["left-length"] = float(fields[5]) * PT_TO_MM
            nodes[-1]["right-length"] = float(fields[6]) * PT_TO_MM
        elif fields[:2] == ["S101", "RECURSE"] and nodes:
            nodes[-1]["recurse"] = True
        elif fields[:2] == ["S101", "LEAFNODE"] and nodes:
            nodes[-1]["recurse"] = False

    if not nodes:
        raise SystemExit(f"no source brush nodes for landmass {landmass}")
    return nodes


def forest(nodes):
    roots = []
    stack = []
    for node in nodes:
        node["children"] = []
        while stack and stack[-1]["depth"] >= node["depth"]:
            stack.pop()
        (stack[-1]["children"] if stack else roots).append(node)
        stack.append(node)
    return roots


def endpoint_error(a, b):
    direct = (math.dist(a["path-start"], b["path-start"])
              + math.dist(a["path-end"], b["path-end"])) / 2
    reverse = (math.dist(a["path-start"], b["path-end"])
               + math.dist(a["path-end"], b["path-start"])) / 2
    return min(direct, reverse)


def pair_trees(source_nodes, typst_nodes):
    source_roots = forest(source_nodes)
    typst_roots = forest(typst_nodes)
    candidates = sorted((endpoint_error(s, t), si, ti)
                        for si, s in enumerate(source_roots)
                        for ti, t in enumerate(typst_roots))
    used_s, used_t, roots = set(), set(), []
    for error, si, ti in candidates:
        if si not in used_s and ti not in used_t:
            used_s.add(si)
            used_t.add(ti)
            roots.append((error, source_roots[si], typst_roots[ti]))

    pairs, divergences = [], []

    def walk(source, typst):
        error = endpoint_error(source, typst)
        pairs.append((error, source, typst))
        if source["recurse"] != typst["recurse"]:
            divergences.append((source, typst, error))
            return
        if source["recurse"]:
            left, right = source["children"], typst["children"]
            if len(left) != len(right):
                divergences.append((source, typst, error))
            count = min(len(left), len(right))
            assignment = min(itertools.permutations(right, count), key=lambda order:
                sum(endpoint_error(a, b) for a, b in zip(left[:count], order)))
            for a, b in zip(left[:count], assignment):
                walk(a, b)

    for _, source, typst in roots:
        walk(source, typst)
    return roots, pairs, divergences


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    log, typst_json, landmass = sys.argv[1], sys.argv[2], int(sys.argv[3])
    source = load_source(log, landmass)
    trace = json.loads(Path(typst_json).read_text())
    entry = next((item for item in trace if item["landmass"] == landmass), None)
    if entry is None:
        raise SystemExit(f"no Typst trace for visible landmass {landmass}")
    typst = [dict(node, children=[]) for node in entry["nodes"]
             if node["stage"] == "thin"]
    roots, pairs, divergences = pair_trees(source, typst)
    print(f"landmass {landmass}: source/Typst nodes {len(source)}/{len(typst)}")
    print(f"paired roots {len(roots)}; root errors: "
          + ", ".join(f"{error:.5f} mm" for error, _, _ in roots))
    print(f"parent-aware pairs {len(pairs)}; within 0.1 mm "
          f"{sum(e <= 0.1 for e, _, _ in pairs)}; decisions agree "
          f"{sum(s['recurse'] == t['recurse'] for _, s, t in pairs)}/{len(pairs)}")
    print("first branch divergences:")
    for source_node, typst_node, error in divergences[:12]:
        print(f"  depth {source_node['depth']} source "
              f"{source_node['recurse']} {source_node['path-start']} -> "
              f"{source_node['path-end']} w={source_node['width-min']:.5f}.."
              f"{source_node['width-max']:.5f} cut="
              f"{source_node['cut-time']:.5f}/w{source_node['cut-width']:.5f} "
              f"qends={source_node['width-start']:.5f}/"
              f"{source_node['width-end']:.5f}; "
              f"({source_node['left-length']:.3f}/{source_node['right-length']:.3f} mm); "
              f"Typst {typst_node['recurse']} "
              f"{typst_node['path-start']} -> {typst_node['path-end']} "
              f"w={typst_node['width-min']:.5f}..{typst_node['width-max']:.5f} "
              f"cut={typst_node['cut-param']}/w{typst_node['target']:.5f} "
              f"qends={typst_node.get('width-start')}/"
              f"{typst_node.get('width-end')}; "
              f"({typst_node['left-length']:.3f}/{typst_node['right-length']:.3f} mm); "
              f"endpoint error {error:.5f} mm")


if __name__ == "__main__":
    main()
