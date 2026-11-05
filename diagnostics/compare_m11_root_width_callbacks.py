#!/usr/bin/env python3
"""Compare source root q-width knots with Typst's callback-width trace.

Usage: compare_m11_root_width_callbacks.py MPOST_LOG TYPST_JSON
"""

import json
import sys
from collections import defaultdict
from pathlib import Path


def fixed(value: str) -> int:
    whole, high, low = map(int, value.split(":"))
    return whole * 65536 + high * 256 + low


def source_widths(log_path: str) -> dict[int, list[tuple[int, int]]]:
    active = None
    widths: dict[int, list[tuple[int, int]]] = defaultdict(list)
    for line in Path(log_path).read_text().splitlines():
        fields = line.split()
        if fields[:1] == ["M11-COAST-BEGIN"]:
            active = int(fields[1])
        elif fields[:1] == ["M11-COAST-END"]:
            active = None
        elif active is not None and fields[:1] == ["M11-ROOTQ"]:
            widths[active].append((int(fields[2]), fixed(fields[4])))
    return widths


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source = source_widths(sys.argv[1])
    typst = json.loads(Path(sys.argv[2]).read_text())
    for entry in typst:
        mass = entry["landmass"]
        expected = source.get(mass, [])
        actual = entry["source-width-fixed"]
        pairs = [(index, value, actual[index]) for index, value in expected
                 if index < len(actual)]
        if not pairs:
            continue
        deltas = [(index, source_value - typst_value)
                  for index, source_value, typst_value in pairs]
        maximum = max(abs(delta) for _, delta in deltas)
        max_indices = [index for index, delta in deltas
                       if abs(delta) == maximum]
        print(f"mass {mass}: knots source/Typst {len(expected)}/{len(actual)}; "
              f"exact {sum(delta == 0 for _, delta in deltas)}/{len(deltas)}; "
              f"mean/max abs {sum(abs(delta) for _, delta in deltas) / len(deltas):.3f}/"
              f"{maximum} fixed units; max at {max_indices}")
        first = pairs[0]
        last = pairs[-1]
        print(f"  endpoint widths source/Typst "
              f"{first[1]}/{first[2]} -> {last[1]}/{last[2]}")


if __name__ == "__main__":
    main()
