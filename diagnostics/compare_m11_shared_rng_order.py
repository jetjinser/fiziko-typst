#!/usr/bin/env python3
"""Compare full shared-stream M11 tube calls with source trace order.

Usage: compare_m11_shared_rng_order.py MPOST_LOG TYPOGRAPHY_ORDER_JSON
"""

import json
from collections import Counter, defaultdict
from pathlib import Path


SEGMENT_CALLS = {
    (1, 1): 1,
    (0, 0): 2,
    (0, 2): 3,
    (1, 0): 4,
    (1, 2): 5,
    (0, 1): 6,
}


def main():
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("typst_order_json", type=Path)
    args = parser.parse_args()
    source = defaultdict(Counter)
    for line in args.source_log.read_text().splitlines():
        f = line.split()
        if f and f[0] == "M11LANE":
            source[int(f[1])][int(f[2])] += int(f[3])
    data = json.loads(args.typst_order_json.read_text())
    while isinstance(data, list) and len(data) == 1:
        data = data[0]

    for order_name in ("current-order", "source-order"):
        run = data[order_name]
        observed = defaultdict(int)
        sequence = []
        for row in run["rows"]:
            call = SEGMENT_CALLS[(row["strand"], row["segment"])]
            sequence.append(call)
            observed[call] += row["calls"]
        absolute_error = 0
        print(f"{order_name} calls={run['calls']} draw-order={sequence}")
        for call in range(1, 7):
            target = sum(source[call].values())
            error = abs(target - observed[call])
            absolute_error += error
            print(f"  call={call} source/typst={target}/{observed[call]} "
                  f"delta={observed[call] - target:+d}")
        print(f"  source-total={sum(sum(v.values()) for v in source.values())} "
              f"typst-total={run['calls']} per-call L1={absolute_error}")


if __name__ == "__main__":
    main()
