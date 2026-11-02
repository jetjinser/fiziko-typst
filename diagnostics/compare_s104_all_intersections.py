#!/usr/bin/env python3
"""Compare the fixed-point packet replay with all instrumented S104 rows.

Usage: compare_s104_all_intersections.py MPOST_LOG
"""

import argparse
from pathlib import Path

from replay_s104_thin_intersections import fixed_replay, load, replay


def same_pair(actual, expected) -> bool:
    actual_hit = actual[0] >= 0 and actual[1] >= 0
    expected_hit = expected[0] >= 0 and expected[1] >= 0
    if not actual_hit or not expected_hit:
        return actual_hit == expected_hit
    return max(abs(actual[0] - expected[0]),
               abs(actual[1] - expected[1])) <= 1 / 65536


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log")
    args = parser.parse_args()

    rows = set()
    for line in Path(args.log).read_text().splitlines():
        fields = line.split()
        if fields and fields[0] == "S104-FIRST":
            rows.add(float(fields[1]))

    total = matched = cuts = cuts_matched = 0
    mismatches = []
    cut_mismatches = []
    for row in sorted(rows):
        nodes = load(args.log, row)
        for serial, node in sorted(nodes.items()):
            if (node["thin"] is None or node["hit"] is None
                    or node["hit_x"] is None or len(node["first"]) < 2
                    or len(node["rays"][1]) != 4
                    or len(node["rays"][2]) != 4
                    or len(node["y_controls"]) != len(node["controls"])):
                continue
            actual, expected = fixed_replay(node)
            for pair_index, (got, want) in enumerate(zip(actual, expected)):
                total += 1
                if same_pair(got, want):
                    matched += 1
                else:
                    mismatches.append((row, serial, pair_index, got, want))
            decision = replay(node)
            raw_match = max(
                abs(decision["cut1"] - decision["source_cut1"]),
                abs(decision["cut2"] - decision["source_cut2"]),
            ) <= 0.00002
            cut_match = abs(decision["chosen"] - decision["source_cut"]) <= 0.00002
            cuts += 1
            if raw_match and cut_match:
                cuts_matched += 1
            else:
                cut_mismatches.append((row, serial, raw_match, cut_match, decision))

    print(f"rows: {len(rows)}; source cut decisions: {cuts_matched}/{cuts}")
    print(f"raw direct/reverse pairs: {matched}/{total}")
    if cut_mismatches:
        for row, serial, raw_match, cut_match, decision in cut_mismatches[:20]:
            print(f"cut mismatch row={row:g} node={serial} "
                  f"raw={raw_match} selected={cut_match}: {decision}")
    if mismatches or cut_mismatches:
        for row, serial, index, got, want in mismatches[:20]:
            print(f"mismatch row={row:g} node={serial} pair={index}: "
                  f"replay={got} source={want}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
