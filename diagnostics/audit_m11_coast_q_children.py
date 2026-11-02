#!/usr/bin/env python3
"""Check recursive M11 coast q-path endpoints against parent cuts.

Usage: audit_m11_coast_q_children.py MPOST_LOG LANDMASS
"""

import math
import sys
from pathlib import Path

SCALE = 1 << 16


def fixed(value: str) -> int:
    if ":" not in value:
        return int(value) * SCALE
    whole, high, low = map(int, value.split(":"))
    return whole * SCALE + high * 256 + low


def parse(path: str, landmass: int) -> list[dict]:
    active = False
    pending = []
    nodes = []
    current = None
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if fields[:1] == ["M11-COAST-BEGIN"]:
            active = int(fields[1]) == landmass
            pending = []
            continue
        if fields[:1] == ["M11-COAST-END"]:
            active = False
            continue
        if not active:
            continue
        if fields[:1] == ["S101-QKNOT-FIX"]:
            pending.append((fixed(fields[3]), fixed(fields[4])))
        elif fields[:2] == ["S101", "NODE"]:
            current = {"depth": int(fields[2]), "q": pending,
                       "children": [], "cut": None,
                       "controls": [None, None, None, None],
                       "recurse": False}
            nodes.append(current)
            pending = []
        elif fields[:1] == ["S101-QCTRLPT-FIX"] and current:
            current["controls"][int(fields[2])] = [fixed(fields[3]), fixed(fields[4])]
        elif fields[:1] == ["S101-CUTFIX"] and current:
            current["cut"] = fixed(fields[2])
        elif fields[:2] == ["S101", "RECURSE"] and current:
            current["recurse"] = True

    stack = []
    for node in nodes:
        while stack and stack[-1]["depth"] >= node["depth"]:
            stack.pop()
        if stack:
            stack[-1]["children"].append(node)
        stack.append(node)
    return nodes


def mix(a: int, b: int, t: int) -> int:
    diff = (b - a) * t
    rounded = (diff + SCALE // 2) // SCALE if diff >= 0 else -((-diff + SCALE // 2) // SCALE)
    return a + rounded


def q_at(controls: list[list[int]], t: int) -> tuple[int, int]:
    f = t % SCALE
    a = [mix(x, y, f) for x, y in zip(controls[0], controls[1])]
    b = [mix(x, y, f) for x, y in zip(controls[1], controls[2])]
    c = [mix(x, y, f) for x, y in zip(controls[2], controls[3])]
    d = [mix(x, y, f) for x, y in zip(a, b)]
    e = [mix(x, y, f) for x, y in zip(b, c)]
    return tuple(mix(x, y, f) for x, y in zip(d, e))


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    mass = int(sys.argv[2])
    nodes = parse(sys.argv[1], mass)
    checked = 0
    maximum = 0.0
    exact_child_knot_pairs = 0
    for node in nodes:
        if (not node["recurse"] or len(node["children"]) != 2
                or node["cut"] is None or any(p is None for p in node["controls"])):
            continue
        left, right = node["children"]
        expected = q_at(node["controls"], node["cut"])
        errors = (math.dist(expected, left["q"][-1]),
                  math.dist(expected, right["q"][0]))
        checked += 1
        maximum = max(maximum, *errors)
        if max(errors) > 1:
            print(f"depth {node['depth']} t={node['cut'] / SCALE:.5f}: "
                  f"parent cut {expected}, child endpoints "
                  f"{left['q'][-1]}/{right['q'][0]}, errors "
                  f"{errors[0]:.3f}/{errors[1]:.3f} fixed units")
        whole = node["cut"] // SCALE
        fraction = node["cut"] % SCALE
        if fraction:
            expected_left = node["q"][:whole + 1] + [expected]
            expected_right = [expected] + node["q"][whole + 1:]
        else:
            expected_left = node["q"][:whole + 1]
            expected_right = node["q"][whole:]
        if left["q"] == expected_left and right["q"] == expected_right:
            exact_child_knot_pairs += 1
        else:
            print(f"depth {node['depth']} t={node['cut'] / SCALE:.5f}: "
                  f"child knot sequence differs (left {len(left['q'])}/"
                  f"{len(expected_left)}, right {len(right['q'])}/"
                  f"{len(expected_right)} knots)")
    print(f"landmass {mass}: checked {checked} recursive q cuts; "
          f"maximum child-endpoint error {maximum:.3f} fixed units; "
          f"exact child knot sequences {exact_child_knot_pairs}/{checked}")


if __name__ == "__main__":
    main()
