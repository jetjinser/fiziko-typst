#!/usr/bin/env python3
"""Rebuild a traced shadowCut connector with MetaPost's `..` join solver."""

import argparse
import math
import os
import re
import shutil
import subprocess
from pathlib import Path

from audit_m11_shadow_connector_curves import (
    derivative,
    read_post_cut_curves,
    read_pre_cut_curves,
    source_cut_records,
    splice,
)


def point(curve, t):
    u = 1 - t
    return tuple(
        u**3 * curve[0][axis]
        + 3 * u**2 * t * curve[1][axis]
        + 3 * u * t**2 * curve[2][axis]
        + t**3 * curve[3][axis]
        for axis in range(2)
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_trace", type=Path)
    parser.add_argument("--output", type=Path,
                        default=Path("/tmp/m11-cross-knot-join"))
    parser.add_argument("--call", type=int, default=4)
    parser.add_argument("--lane", type=int, default=6)
    args = parser.parse_args()

    key = (args.call, args.lane)
    curves = read_pre_cut_curves(args.source_trace)[key]
    post = read_post_cut_curves(args.source_trace)[key]
    segments = [(float(i), float(i + 1), False) for i in range(len(curves))]
    for cut_time, path_length in source_cut_records(args.source_trace)[key]:
        if 0.1 < cut_time < path_length - 0.1:
            segments = splice(segments, cut_time)
    joins = [(index, segment) for index, segment in enumerate(segments)
             if segment[2]
             and math.floor(segment[0]) != math.floor(segment[1] - 1e-12)]
    if len(joins) != 1:
        raise ValueError(f"expected one cross-knot connector, found {len(joins)}")
    post_index, (start, end, _connector) = joins[0]
    first, last = math.floor(start), math.floor(end - 1e-12)
    start_point = point(curves[first], start - first)
    end_point = point(curves[last], end - last)
    start_tangent = derivative(curves[first], start - first)
    end_tangent = derivative(curves[last], end - last)
    start_angle = math.degrees(math.atan2(start_tangent[1], start_tangent[0]))
    end_angle = math.degrees(math.atan2(end_tangent[1], end_tangent[0]))

    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    upstream = Path(os.environ["FIZIKO_UPSTREAM_PATH"])
    shutil.copy2(upstream / "fiziko.mp", output / "fiziko.mp")
    mp = f"""input fiziko.mp;
beginfig(0);
path connector;
connector := ({start_point[0]:.10f}mm,{start_point[1]:.10f}mm)
  {{dir {start_angle:.10f}}} .. {{dir {end_angle:.10f}}}
  ({end_point[0]:.10f}mm,{end_point[1]:.10f}mm);
message "JOIN " & decimal(xpart(postcontrol 0 of connector)/mm) & " "
  & decimal(ypart(postcontrol 0 of connector)/mm) & " "
  & decimal(xpart(precontrol 1 of connector)/mm) & " "
  & decimal(ypart(precontrol 1 of connector)/mm);
endfig;
end
"""
    (output / "join.mp").write_text(mp)
    run = subprocess.run(
        ["mpost", "-interaction=nonstopmode", "-halt-on-error",
         "-jobname=join", "join.mp"], cwd=output, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=True,
    )
    match = re.search(r"JOIN\s+([-+\d.]+)\s+([-+\d.]+)\s+([-+\d.]+)\s+([-+\d.]+)",
                      run.stdout)
    if not match:
        raise RuntimeError(f"MetaPost join controls missing from output: {run.stdout}")
    predicted = tuple((float(match.group(i)), float(match.group(i + 1)))
                      for i in (1, 3))
    actual = post[post_index][1:3]
    errors = tuple(math.dist(a, b) for a, b in zip(predicted, actual))
    print(f"call/lane={args.call}/{args.lane} segment={post_index} "
          f"source-time=[{start:.5f},{end:.5f}]")
    print(f"MetaPost join controls: {predicted[0]} / {predicted[1]} mm")
    print(f"source trace controls:  {actual[0]} / {actual[1]} mm")
    print(f"control errors: {errors[0]:.8g}/{errors[1]:.8g} mm; "
          f"max={max(errors):.8g} mm")


if __name__ == "__main__":
    main()
