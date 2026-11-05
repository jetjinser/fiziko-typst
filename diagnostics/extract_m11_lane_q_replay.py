#!/usr/bin/env python3
"""Extract the three M11 source-q lane trees from the modeled tube trace."""

import argparse
import json
from pathlib import Path


SELECTION = ((4, 2, 0, 5), (4, 6, 0, 1), (5, 2, 2, 5))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    data = json.loads(args.trace.read_text())
    # Typst query wraps the metadata value in a one-item content array.
    traces = data[0]
    replay = []
    for call, source_lane, segment, typst_lane in SELECTION:
        piece = next(item for item in traces[segment]["inner-lanes"]
                     if item["lane"] == typst_lane and item["piece"] == 0)
        replay.append({"call": call, "lane": source_lane,
                       "q-nodes": piece["reconstructed-q-nodes"]})
    args.output.write_text(json.dumps(replay, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    main()
