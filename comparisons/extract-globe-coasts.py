"""Extract and convert the pinned upstream land outlines for M11 parity."""

import hashlib
import os
from pathlib import Path
import re
import sys


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: extract-globe-coasts.py OUTPUT.typ")
    upstream = Path(os.environ["FIZIKO_UPSTREAM_PATH"]) / "fiziko.mp"
    text = upstream.read_text()
    masses = re.findall(r"(?m)^landmass([0-9]+) := (.*?);$", text)
    if len(masses) != 8:
        raise SystemExit(f"expected 8 pinned landmasses, found {len(masses)}")

    digest = hashlib.sha256(upstream.read_bytes()).hexdigest()
    lines = [
        "// Geographic outlines copied and transformed from pinned upstream Fiziko.",
        f"// Source: fiziko.mp, SHA-256 {digest}",
        "// Upstream coordinates are (longitude, colatitude); this converts to",
        "// this port's (longitude, latitude) convention for comparison fixture M11.",
        "#let upstream-landmasses = (",
    ]
    point_count = 0
    for _, path in masses:
        points = [(float(lon), 90.0 - float(colat)) for lon, colat in
                  re.findall(r"\(([0-9.]+),\s*([0-9.]+)\)", path)]
        point_count += len(points)
        lines.append("  (")
        for i in range(0, len(points), 5):
            lines.append("    " + ", ".join(
                f"({-lon:g}, {lat:g})" for lon, lat in points[i:i + 5]
            ) + ",")
        lines.append("  ),")
    lines.append(")")
    Path(sys.argv[1]).write_text("\n".join(lines) + "\n")
    print(f"Wrote {len(masses)} paths / {point_count} vertices from {digest}")


if __name__ == "__main__":
    main()
