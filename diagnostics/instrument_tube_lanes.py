#!/usr/bin/env python3
"""Mark each source longitudinal tube lane before its brush is drawn.

Usage: instrument_tube_lanes.py INSTRUMENTED_FIZIKO_MP OUTPUT_MP
"""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source = Path(sys.argv[1]).read_text()
    lane_call = "                    brushGenerate (currentPath,\n"
    if source.count(lane_call) != 1:
        raise ValueError(f"expected one tube lane brush call, found {source.count(lane_call)}")
    source = source.replace(
        lane_call,
        '                    message "TUBE-LANE " & decimal(i) & " "'
        ' & decimal(k) & " " & decimal(bw1) & " " & decimal(arclength(currentPath));\n'
        + lane_call,
    )
    Path(sys.argv[2]).write_text(source)


if __name__ == "__main__":
    main()
