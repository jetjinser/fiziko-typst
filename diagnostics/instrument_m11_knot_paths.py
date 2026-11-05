#!/usr/bin/env python3
"""Add source-path sample messages to a copy of the pinned M11 driver."""

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) not in (3, 4):
        raise SystemExit(
            "usage: instrument_m11_knot_paths.py MAIN_MP OUTPUT_MP [STEP_DENOMINATOR]"
        )
    source_path, output_path = map(Path, sys.argv[1:3])
    step_denominator = int(sys.argv[3]) if len(sys.argv) == 4 else 8
    if step_denominator <= 0:
        raise SystemExit("STEP_DENOMINATOR must be positive")
    source = source_path.read_text()
    anchor = '  addStrandToKnot(weave)(wa,.8mm,"l","-1,1,-1,1");'
    trace = f"""  numeric traceX, traceY, traceXInt, traceYInt,
        traceXHigh, traceYHigh, traceXLow, traceYLow,
        traceCurveIndex, traceCurveControl, traceStrand;
  path tracePath;
  pair tracePoint;
  traceX := mm;
  traceXInt := floor(traceX);
  traceXHigh := floor((traceX-traceXInt)*256);
  traceXLow := round(((traceX-traceXInt)*256-traceXHigh)*256);
  if traceXLow = 256: traceXHigh := traceXHigh+1; traceXLow := 0; fi;
  if traceXHigh = 256: traceXInt := traceXInt+1; traceXHigh := 0; fi;
  message "M11PATHSCALE " & decimal(traceXInt) & " "
    & decimal(traceXHigh) & " " & decimal(traceXLow);
  for ti := 0 step 1/{step_denominator} until length(wa):
    message "M11PATH A " & decimal(ti) & " " & decimal(xpart(point ti of wa)/mm) & " " & decimal(44-ypart(point ti of wa)/mm);
    message "M11PATH B " & decimal(ti) & " " & decimal(xpart(point ti of wb)/mm) & " " & decimal(44-ypart(point ti of wb)/mm);
    traceX := xpart(point ti of wa);
    traceY := 44mm - ypart(point ti of wa);
    traceXInt := floor(traceX);
    traceYInt := floor(traceY);
    traceXHigh := floor((traceX-traceXInt)*256);
    traceYHigh := floor((traceY-traceYInt)*256);
    traceXLow := round(((traceX-traceXInt)*256-traceXHigh)*256);
    traceYLow := round(((traceY-traceYInt)*256-traceYHigh)*256);
    if traceXLow = 256: traceXHigh := traceXHigh+1; traceXLow := 0; fi;
    if traceYLow = 256: traceYHigh := traceYHigh+1; traceYLow := 0; fi;
    if traceXHigh = 256: traceXInt := traceXInt+1; traceXHigh := 0; fi;
    if traceYHigh = 256: traceYInt := traceYInt+1; traceYHigh := 0; fi;
    message "M11PATHFIX A " & decimal(ti) & " " & decimal(traceXInt) & " "
      & decimal(traceXHigh) & " " & decimal(traceXLow) & " "
      & decimal(traceYInt) & " " & decimal(traceYHigh) & " "
      & decimal(traceYLow);
    traceX := xpart(point ti of wb);
    traceY := 44mm - ypart(point ti of wb);
    traceXInt := floor(traceX);
    traceYInt := floor(traceY);
    traceXHigh := floor((traceX-traceXInt)*256);
    traceYHigh := floor((traceY-traceYInt)*256);
    traceXLow := round(((traceX-traceXInt)*256-traceXHigh)*256);
    traceYLow := round(((traceY-traceYInt)*256-traceYHigh)*256);
    if traceXLow = 256: traceXHigh := traceXHigh+1; traceXLow := 0; fi;
    if traceYLow = 256: traceYHigh := traceYHigh+1; traceYLow := 0; fi;
    if traceXHigh = 256: traceXInt := traceXInt+1; traceXHigh := 0; fi;
    if traceYHigh = 256: traceYInt := traceYInt+1; traceYHigh := 0; fi;
    message "M11PATHFIX B " & decimal(ti) & " " & decimal(traceXInt) & " "
      & decimal(traceXHigh) & " " & decimal(traceXLow) & " "
      & decimal(traceYInt) & " " & decimal(traceYHigh) & " "
      & decimal(traceYLow);
  endfor;
  for traceStrand := 0 upto 1:
    if traceStrand = 0: tracePath := wa; else: tracePath := wb; fi;
    for traceCurveIndex := 0 step 1 until length(tracePath)-1:
      for traceCurveControl := 0 upto 3:
        if traceCurveControl = 0:
          tracePoint := point traceCurveIndex of tracePath;
        elseif traceCurveControl = 1:
          tracePoint := postcontrol traceCurveIndex of tracePath;
        elseif traceCurveControl = 2:
          tracePoint := precontrol (traceCurveIndex+1) of tracePath;
        else:
          tracePoint := point (traceCurveIndex+1) of tracePath;
        fi;
        traceX := xpart(tracePoint);
        traceY := 44mm - ypart(tracePoint);
        traceXInt := floor(traceX);
        traceYInt := floor(traceY);
        traceXHigh := floor((traceX-traceXInt)*256);
        traceYHigh := floor((traceY-traceYInt)*256);
        traceXLow := round(((traceX-traceXInt)*256-traceXHigh)*256);
        traceYLow := round(((traceY-traceYInt)*256-traceYHigh)*256);
        if traceXLow = 256: traceXHigh := traceXHigh+1; traceXLow := 0; fi;
        if traceYLow = 256: traceYHigh := traceYHigh+1; traceYLow := 0; fi;
        if traceXHigh = 256: traceXInt := traceXInt+1; traceXHigh := 0; fi;
        if traceYHigh = 256: traceYInt := traceYInt+1; traceYHigh := 0; fi;
        if traceStrand = 0:
          message "M11PATHCTRL A " & decimal(traceCurveIndex) & " "
            & decimal(traceCurveControl) & " " & decimal(traceXInt) & " "
            & decimal(traceXHigh) & " " & decimal(traceXLow) & " "
            & decimal(traceYInt) & " " & decimal(traceYHigh) & " "
            & decimal(traceYLow);
        else:
          message "M11PATHCTRL B " & decimal(traceCurveIndex) & " "
            & decimal(traceCurveControl) & " " & decimal(traceXInt) & " "
            & decimal(traceXHigh) & " " & decimal(traceXLow) & " "
            & decimal(traceYInt) & " " & decimal(traceYHigh) & " "
            & decimal(traceYLow);
        fi;
      endfor;
    endfor;
  endfor;
"""
    if source.count(anchor) != 1:
        raise ValueError(f"expected one M11 strand hook, found {source.count(anchor)}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(source.replace(anchor, trace + anchor))


if __name__ == "__main__":
    main()
