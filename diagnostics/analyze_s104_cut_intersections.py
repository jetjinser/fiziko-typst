#!/usr/bin/env python3
"""Compare traced S104 cuts with exact roots of their source cubic width paths.

Usage: analyze_s104_cut_intersections.py MPOST_LOG ROW
"""

import sys
from pathlib import Path


def decode_16_16(high, low):
    return (int(high) + int(low) / 256) / 256


def cubic(values, u):
    a, b, c, d = values
    v = 1 - u
    return v**3 * a + 3 * v * v * u * b + 3 * v * u * u * c + u**3 * d


def roots(values, target):
    """Find all sign-changing roots on a cubic segment by bracketing."""
    found = []
    steps = 256
    lo = 0.0
    flo = cubic(values, lo) - target
    for i in range(1, steps + 1):
        hi = i / steps
        fhi = cubic(values, hi) - target
        if flo == 0:
            found.append(lo)
        elif flo * fhi < 0:
            a, b, fa = lo, hi, flo
            for _ in range(48):
                mid = (a + b) / 2
                fm = cubic(values, mid) - target
                if fa * fm <= 0:
                    b = mid
                else:
                    a, fa = mid, fm
            found.append((a + b) / 2)
        lo, flo = hi, fhi
    if flo == 0:
        found.append(1.0)
    return found


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    row = float(sys.argv[2])
    controls = {}
    node_fix = {}
    ids = {}
    hit_times = {}

    for line in Path(sys.argv[1]).read_text().splitlines():
        p = line.split()
        if not p or p[0] not in {
            "S104-OCTRL", "S104-OFIX", "S104-OUTER-ID", "S104-HIT"
        }:
            continue
        if len(p) < 4 or abs(float(p[1]) - row) > 0.00001:
            continue
        if p[0] == "S104-OCTRL":
            serial, segment = int(p[2]), int(p[4])
            controls[(serial, segment)] = [
                decode_16_16(p[i], p[i + 1]) for i in range(5, 13, 2)
            ]
        elif p[0] == "S104-OFIX":
            serial = int(p[2])
            threshold = decode_16_16(p[8], p[9])
            cut = decode_16_16(p[10], p[11])
            node_fix[serial] = (threshold, cut)
        elif p[0] == "S104-OUTER-ID":
            ids[int(p[2])] = int(p[3])
        elif p[0] == "S104-HIT":
            # t1/t2 verify that this is an actual two-ray cut candidate;
            # the selected whole-path time is retained at higher precision
            # in the paired S104-OFIX record.
            hit_times[int(p[2])] = tuple(map(float, p[7:9]))

    paired = []
    for serial, node in ids.items():
        if serial not in hit_times or serial not in node_fix:
            continue
        threshold, cut = node_fix[serial]
        if cut <= 0:
            continue
        segment = int(cut)
        u = cut - segment
        if u == 0 and segment > 0:
            segment -= 1
            u = 1.0
        curve = controls.get((serial, segment))
        if curve is None:
            continue
        exact_roots = [s + root for (n, s), ys in controls.items()
                       if n == serial for root in roots(ys, threshold)]
        if not exact_roots:
            continue
        nearest = min(exact_roots, key=lambda t: abs(t - cut))
        residual = cubic(curve, u) - threshold
        paired.append((serial, node, cut, nearest, residual, hit_times[serial]))

    if not paired:
        raise SystemExit("no source cut/control pairs found for that row")
    print("serial node source-t cubic-root delta-16.16 width-residual ray-hits")
    for serial, node, cut, nearest, residual, hits in paired:
        print(f"{serial:6d} {node:4d} {cut:.12f} {nearest:.12f} "
              f"{(cut-nearest)*65536:+.3f} {residual:+.12g} {hits}")


if __name__ == "__main__":
    main()
