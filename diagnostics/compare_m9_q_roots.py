#!/usr/bin/env python3
"""Compare source cLine q cubics with the matching M9 Typst q replay roots."""

import itertools
import json
import math
import sys
from collections import defaultdict
from pathlib import Path


def fixed(hi, lo):
    return int(hi) * 256 + int(lo)


def source_roots(path):
    roots = defaultdict(list)
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if len(fields) != 19 or fields[0] != "WBOQ":
            continue
        root, segment = map(int, fields[1:3])
        values = [fixed(fields[i], fields[i + 1])
                  for i in range(3, 19, 2)]
        roots[root].append((segment, tuple(
            (values[i], values[i + 1]) for i in range(0, 8, 2)
        )))
    return [tuple(curve for _, curve in sorted(roots[index]))
            for index in sorted(roots)]


def endpoint_error(a, b):
    return (math.dist(a[0][0], b[0][0])
            + math.dist(a[-1][-1], b[-1][-1])) / 2


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: compare_m9_q_roots.py MPOST_LOG TYPST_JSON")
    source = source_roots(sys.argv[1])
    trace = json.loads(Path(sys.argv[2]).read_text())
    typst = [tuple(tuple(tuple(point) for point in curve)
                   for curve in node["q-curves-fixed"])
             for node in trace.get("q-nodes", ())
             if node["stage"] == "outer" and node["depth"] == 0
             and node.get("q-curves-fixed")]
    if not source or not typst:
        raise SystemExit("trace is missing source WBOQ or Typst q-nodes")
    count = min(len(source), len(typst))
    assignment = min(itertools.permutations(range(len(typst)), count),
                     key=lambda order: sum(endpoint_error(source[i], typst[j])
                                           for i, j in enumerate(order)))
    print(f"q replay roots source/Typst: {len(source)}/{len(typst)}")
    for i, j in enumerate(assignment):
        src, typ = source[i], typst[j]
        paired = min(len(src), len(typ))
        print(f"root {i}/{j}: segments {len(src)}/{len(typ)}; endpoint error "
              f"{endpoint_error(src, typ):.3f} fixed units")
        for axis, label in ((0, "arc x"), (1, "width y")):
            errors = [abs(a[axis] - b[axis])
                      for k in range(paired)
                      for a, b in zip(src[k], typ[k])]
            exact = sum(a[axis] == b[axis]
                        for k in range(paired)
                        for a, b in zip(src[k], typ[k]))
            print(f"  {label}: exact controls {exact}/{paired * 4}; "
                  f"mean/max error {sum(errors) / len(errors):.3f}/"
                  f"{max(errors)} fixed units")
        source_lengths = [curve[-1][0] - curve[0][0] for curve in src]
        typst_lengths = [curve[-1][0] - curve[0][0] for curve in typ]
        paired_lengths = min(len(source_lengths), len(typst_lengths))
        errors = [abs(source_lengths[k] - typst_lengths[k])
                  for k in range(paired_lengths)]
        print(f"  q.x segment increments: mean/max error "
              f"{sum(errors) / len(errors):.3f}/{max(errors)} fixed units")


if __name__ == "__main__":
    main()
