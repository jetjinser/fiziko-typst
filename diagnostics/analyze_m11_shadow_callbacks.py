#!/usr/bin/env python3
"""Summarize integer callback samples after M11 shadowCut path expansion.

Usage: analyze_m11_shadow_callbacks.py MPOST_LOG
"""

import sys
from collections import Counter, defaultdict
from pathlib import Path


def analyze(path):
    before = {}
    after = {}
    callback_time = {}
    callbacks = defaultdict(dict)
    cuts = defaultdict(list)
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
        elif tag == "M11CUT":
            key = (int(fields[1]), int(fields[2]))
            cuts[key].append((float(fields[4]), float(fields[6])))
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
              f"tail={post_end-original_end} max-trace-delta={max_delta:.9g} "
              f"missing={missing}")
    print(f"expanded lanes: {expanded}; callback tails matching the endpoint "
          f"at trace precision: {expanded-mismatched}/{expanded}")

    splice_deltas = Counter()
    near_integer_deltas = Counter()
    splice_mismatches = []
    predicted_deltas = defaultdict(int)
    recovered_times = []
    for key, records in cuts.items():
        accumulated_shift = 0
        for current, following in zip(records, records[1:]):
            cut_time, path_length = current
            if cut_time <= 0.1 or cut_time >= path_length - 0.1:
                continue
            if accumulated_shift:
                recovered_times.append((key, cut_time,
                                        cut_time - accumulated_shift))
            delta = following[1] - path_length
            splice_deltas[delta] += 1
            phase = cut_time % 1
            crosses_knot = min(phase, 1 - phase) < 0.05
            if crosses_knot:
                near_integer_deltas[delta] += 1
            expected_delta = 1 if crosses_knot else 2
            predicted_deltas[key] += expected_delta
            accumulated_shift += expected_delta
            if abs(delta - expected_delta) > 1e-6:
                splice_mismatches.append((cut_time, delta, expected_delta))
    if splice_deltas:
        total = sum(splice_deltas.values())
        summary = ", ".join(
            f"+{int(delta)} path-time: {count}"
            for delta, count in sorted(splice_deltas.items())
        )
        print(f"successful shadow cuts: {total}; next-attempt path-length change: {summary}")
        near = ", ".join(
            f"+{int(delta)}: {count}"
            for delta, count in sorted(near_integer_deltas.items())
        ) or "none"
        print(f"cuts within 0.05 of an integer path time: {near}")
        print(f"integer-knot splice model matches: "
              f"{total-len(splice_mismatches)}/{total}")
        if splice_mismatches:
            print(f"splice-model mismatches: {splice_mismatches}")
        expanded_keys = [key for key in before
                         if key in after and after[key] > before[key]]
        final_matches = sum(
            before[key] + predicted_deltas[key] == after[key]
            for key in expanded_keys
        )
        print(f"predicted expanded path lengths: "
              f"{final_matches}/{len(expanded_keys)}")
        example = next((item for item in recovered_times
                        if item[0] == (4, 2) and abs(item[1] - 28.06259) < 1e-4),
                       None)
        if example:
            key, current_time, original_time = example
            print(f"call={key[0]} lane={key[1]} later cut time "
                  f"{current_time:.5f} maps back to original path time "
                  f"{original_time:.5f}")
    if expanded == 0:
        raise SystemExit("no expanded M11 lanes with callback samples found")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    analyze(sys.argv[1])
