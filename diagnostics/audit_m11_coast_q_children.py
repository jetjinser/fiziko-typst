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
    raw_lines = Path(path).read_text().splitlines()
    lines = []
    i = 0
    while i < len(raw_lines):
        line = raw_lines[i]
        i += 1
        if line.startswith("S101-QCTRL-FIX"):
            while sum(token.count(":") in (0, 2) for token in line.split()[2:]) < 8:
                if i >= len(raw_lines) or raw_lines[i].startswith("S101"):
                    break
                continuation = raw_lines[i].strip()
                i += 1
                last = line.split()[-1]
                line += ("" if last.count(":") < 2 else " ") + continuation
        lines.append(line)
    for line in lines:
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
    print(f"landmass {mass}: checked {checked} recursive q cuts; "
          f"maximum child-endpoint error {maximum:.3f} fixed units")


if __name__ == "__main__":
    main()
