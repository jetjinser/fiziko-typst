#!/usr/bin/env python3
"""Create cubic arc-length inputs from the paired production M11 lane samples."""

from pathlib import Path

from extract_m11_typst_q_inputs import (
    PAIRS, read_source, sample, splice, typst_lane_map,
)

MM_PER_BP = 25.4 / 72


def main(source_log, typst_trace, output):
    cuts, _widths, _calls, _offsets, post_lengths, source_arcs, _curves = read_source(source_log)
    lanes = typst_lane_map(typst_trace)
    groups = []
    for key, pair in PAIRS.items():
        points = lanes[pair]
        segments = [(float(i), float(i + 1)) for i in range(len(points) // 4)]
        for cut_time, _length in cuts[key]:
            if cut_time >= 0:
                segments = splice(segments, cut_time)
        if len(segments) != post_lengths[key]:
            raise ValueError(f"post-shadow segment mismatch for {key}")
        rows = []
        for i in range(len(segments)):
            samples = []
            for quarter in range(5):
                source_time = segments[i][0] + (segments[i][1] - segments[i][0]) * quarter / 4
                xy = sample(points, source_time)
                samples.append(tuple(value / MM_PER_BP for value in xy))
            expected = source_arcs[key][i + 1] - (source_arcs[key].get(i, 0))
            rows.append((samples, expected))
        groups.append((key, rows))

    def pair_text(p):
        return f"({p[0]:.12f}, {p[1]:.12f})"

    lines = ["#let m11-production-arc-fixture = ("]
    for (call, lane), rows in groups:
        encoded = []
        for samples, expected in rows:
            # The arc fitter uses p0, p25, p75 and p100; keep p50 for an
            # independent midpoint fit in the Typst diagnostic too.
            encoded.append(
                f"(samples: ({', '.join(pair_text(p) for p in samples)}), expected: {expected}),"
            )
        lines.append(f"  (call: {call}, lane: {lane}, segments: (")
        lines.extend(f"    {row}" for row in encoded)
        lines.append("  )),")
    lines.append(")")
    Path(output).write_text("\n".join(lines) + "\n")
    print(f"wrote {sum(len(rows) for _, rows in groups)} post-shadow lane cubic samples")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("typst_trace", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    main(args.source_log, args.typst_trace, args.output)
