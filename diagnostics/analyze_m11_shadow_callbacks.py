#!/usr/bin/env python3
"""Summarize integer callback samples after M11 shadowCut path expansion.

Usage: analyze_m11_shadow_callbacks.py MPOST_LOG
"""

import sys
from collections import defaultdict
from pathlib import Path


def analyze(path):
    before = {}
    after = {}
    callback_time = {}
    callbacks = defaultdict(dict)
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        tag = fields[0]
        if tag == "M11PARAM":
            key = (int(fields[1]), int(fields[2]))
            before[key] = int(fields[3])
        elif tag == "M11POSTPARAM":
            key = (int(fields[1]), int(fields[2]))
            after[key] = int(fields[3])
        elif tag == "M11WIDTHINPUT":
            key = (int(fields[1]), int(fields[2]))
            callback_time[key] = int(fields[4])
        elif tag == "M11LIGHT":
            key = (int(fields[1]), int(fields[2]))
            if key not in callback_time:
                raise ValueError(f"M11LIGHT without matching M11WIDTHINPUT: {line}")
            callbacks[key][callback_time.pop(key)] = tuple(map(float, fields[5:9]))

    expanded = 0
    mismatched = 0
    for key in sorted(before):
        if key not in after or after[key] <= before[key]:
            continue
        expanded += 1
        original_end = before[key]
        post_end = after[key]
        samples = callbacks[key]
        expected = samples.get(original_end)
        tail_times = range(original_end + 1, post_end + 1)
        missing = [time for time in tail_times if time not in samples]
        deltas = []
        if expected is not None:
            for time in tail_times:
                if time in samples:
                    deltas.append(max(abs(a - b) for a, b in zip(samples[time], expected)))
        max_delta = max(deltas, default=float("inf"))
        if missing or expected is None or max_delta > 1e-7:
            mismatched += 1
        print(f"call={key[0]} lane={key[1]} pre={original_end} post={post_end} "
              f"tail={post_end-original_end} max-endpoint-delta={max_delta:.9g} "
              f"missing={missing}")
    print(f"expanded lanes: {expanded}; endpoint-clamped callback tails: "
          f"{expanded-mismatched}/{expanded}")
    if expanded == 0:
        raise SystemExit("no expanded M11 lanes with callback samples found")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    analyze(sys.argv[1])
