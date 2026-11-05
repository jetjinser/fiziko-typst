#!/usr/bin/env python3
"""Compare complete M11 recursive q cubics on paired source/Typst nodes.

Usage: compare_m11_recursive_q_curves.py MPOST_LOG SOURCE_Q_ORACLE_JSON
"""

import json
import sys
from pathlib import Path

from compare_m11_coast_brush import fixed, load_source, pair_trees


def source_curves(path: str, mass: int) -> list[list[list[list[int]]]]:
    active = False
    pending: dict[int, dict[int, list[int]]] = {}
    nodes = []
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if fields[:2] == ["M11-COAST-BEGIN", str(mass)]:
            active = True
            pending = {}
            continue
        if fields[:2] == ["M11-COAST-END", str(mass)]:
            active = False
            continue
        if not active:
            continue
        if fields[:1] == ["S101-QCURVE-FIX"]:
            segment, control = map(int, fields[2:4])
            if len(fields) != 6:
                raise ValueError(f"wrapped or malformed q control record: {line}")
            pending.setdefault(segment, {})[control] = [
                fixed(fields[4]), fixed(fields[5])]
        elif fields[:2] == ["S101", "NODE"]:
            curves = []
            for segment in range(len(pending)):
                controls = pending[segment]
                if sorted(controls) != [0, 1, 2, 3]:
                    raise ValueError(f"mass {mass}: incomplete q segment {segment}")
                curves.append([controls[index] for index in range(4)])
            nodes.append(curves)
            pending = {}
    return nodes


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    log, oracle_json = sys.argv[1:]
    entries = json.loads(Path(oracle_json).read_text())
    for mass in (1, 2, 4, 5, 7, 8):
        source = load_source(log, mass)
        source_q = source_curves(log, mass)
        if len(source) != len(source_q):
            raise ValueError(f"mass {mass}: {len(source)} nodes but {len(source_q)} q records")
        for node, curves in zip(source, source_q):
            node["q-curves-fixed"] = curves
        entry = next((item for item in entries if item["landmass"] == mass), None)
        if entry is None:
            raise ValueError(f"mass {mass}: no source-q oracle record")
        typst = [dict(node, children=[]) for node in entry["nodes"]
                 if node["stage"] == "thin"]
        _, pairs, _ = pair_trees(source, typst)
        decisions = sum(a["recurse"] == b["recurse"] for _, a, b in pairs)
        exact_q = 0
        for _, source_node, typst_node in pairs:
            a = source_node["q-curves-fixed"]
            b = typst_node.get("q-curves-fixed") or []
            if a == b:
                exact_q += 1
        print(f"mass {mass}: nodes {len(source)}/{len(typst)}; "
              f"decisions {decisions}/{len(pairs)}; "
              f"complete q curves exact {exact_q}/{len(pairs)}")


if __name__ == "__main__":
    main()
