"""Scan sphere and tube stipple density across scales and keyed RNG seeds.

Run inside the locked Nix devshell. Rendered evidence is retained in
build/stage4-surface-scan by default.
"""

import argparse
import json
import math
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
SCALES = (0.5, 1.0, 1.5)
DEFAULTS = {"sphere": 0.55, "tube": 0.56}


def run(command, cwd=None, stdout=subprocess.DEVNULL):
    subprocess.run(command, cwd=cwd, check=True, stdout=stdout)


def gray(path):
    return subprocess.run(["magick", str(path), "-depth", "8", "gray:-"],
                          check=True, capture_output=True).stdout


def raster(pdf, png, ppi, size, cwd):
    run(["gs", "-q", "-dSAFER", "-dBATCH", "-dNOPAUSE", "-dPDFSTOPONERROR",
         "-sDEVICE=pnggray", f"-r{ppi}", f"-g{size[0]}x{size[1]}", "-dFIXEDMEDIA",
         "-dGraphicsAlphaBits=4", "-dTextAlphaBits=4", f"-sOutputFile={png}",
         "-f", str(pdf)], cwd=cwd)


def metrics(source, native):
    if len(source) != len(native) or not source:
        raise ValueError("Raster byte counts differ")
    source_dark = sum(pixel < 128 for pixel in source) / len(source)
    native_dark = sum(pixel < 128 for pixel in native) / len(native)
    source_ink = sum(255 - pixel for pixel in source) / (255 * len(source))
    native_ink = sum(255 - pixel for pixel in native) / (255 * len(native))
    rmse = math.sqrt(sum((a - b) ** 2 for a, b in zip(source, native)) / len(source)) / 255
    return {"rmse": rmse, "dark_ratio": native_dark / source_dark,
            "ink_ratio": native_ink / source_ink}


def region(pixels, size, ppi, rectangle):
    width, height = size
    left, top, right, bottom = (round(mm * ppi / 25.4) for mm in rectangle)
    left, right = max(0, left), min(width, right)
    top, bottom = max(0, top), min(height, bottom)
    return b"".join(pixels[y * width + left:y * width + right]
                    for y in range(top, bottom))


def rect(method, scale):
    if method == "sphere":
        radius = 11 * scale + 1
        return 70 - radius, 22 - radius, 70 + radius, 22 + radius
    radius = 3 * scale + 1
    return 60 - 14 * scale - radius, 22 - 12 * scale - radius, \
        60 + 12 * scale + radius, 22 + 11 * scale + radius


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ppi", type=int, default=600)
    parser.add_argument("--seed", type=int, action="append", dest="seeds")
    parser.add_argument("--output", type=Path, default=ROOT / "build/stage4-surface-scan")
    args = parser.parse_args()
    seeds = args.seeds or [1, 2, 3]
    if not 72 <= args.ppi <= 1200 or any(seed < 0 for seed in seeds):
        parser.error("ppi must be [72, 1200] and seeds nonnegative")
    upstream = os.environ.get("FIZIKO_UPSTREAM_PATH")
    if not upstream:
        parser.error("Use nix develop path:./nix")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    driver = output / "surface_probe.mp"
    driver.write_text(f'''input "{Path(upstream) / "fiziko.mp"}";
numeric scale, figw, figh;
vardef P(expr x, y) = (x*mm, (figh-y)*mm) enddef;
beginfig(601);
  scale := {SCALES[0]}; figw := 120; figh := 44; randomseed := 1;
  draw sphere.s(22mm*scale) shifted P(70,22);
  setbounds currentpicture to (0,0)--(120mm,0)--(120mm,44mm)--(0,44mm)--cycle;
endfig;
beginfig(602);
  scale := {SCALES[1]}; figw := 120; figh := 44; randomseed := 1;
  draw sphere.s(22mm*scale) shifted P(70,22);
  setbounds currentpicture to (0,0)--(120mm,0)--(120mm,44mm)--(0,44mm)--cycle;
endfig;
beginfig(603);
  scale := {SCALES[2]}; figw := 120; figh := 44; randomseed := 1;
  draw sphere.s(22mm*scale) shifted P(70,22);
  setbounds currentpicture to (0,0)--(120mm,0)--(120mm,44mm)--(0,44mm)--cycle;
endfig;
beginfig(611);
  scale := {SCALES[0]}; figw := 120; figh := 44; randomseed := 1;
  draw tube.s(P(60+(89-103)*scale,22+(33-22)*scale)..
    P(60+(103-103)*scale,22+(10-22)*scale)..
    P(60+(115-103)*scale,22+(28-22)*scale))(3mm*scale);
  setbounds currentpicture to (0,0)--(120mm,0)--(120mm,44mm)--(0,44mm)--cycle;
endfig;
beginfig(612);
  scale := {SCALES[1]}; figw := 120; figh := 44; randomseed := 1;
  draw tube.s(P(60+(89-103)*scale,22+(33-22)*scale)..
    P(60+(103-103)*scale,22+(10-22)*scale)..
    P(60+(115-103)*scale,22+(28-22)*scale))(3mm*scale);
  setbounds currentpicture to (0,0)--(120mm,0)--(120mm,44mm)--(0,44mm)--cycle;
endfig;
beginfig(613);
  scale := {SCALES[2]}; figw := 120; figh := 44; randomseed := 1;
  draw tube.s(P(60+(89-103)*scale,22+(33-22)*scale)..
    P(60+(103-103)*scale,22+(10-22)*scale)..
    P(60+(115-103)*scale,22+(28-22)*scale))(3mm*scale);
  setbounds currentpicture to (0,0)--(120mm,0)--(120mm,44mm)--(0,44mm)--cycle;
endfig;
end.
''')
    source_dir = output / "source"
    source_dir.mkdir(exist_ok=True)
    run(["mpost", "-interaction=nonstopmode", "-halt-on-error", str(driver)], cwd=source_dir)
    for figure in (601, 602, 603, 611, 612, 613):
        run(["mptopdf", f"{driver.stem}.{figure}"], cwd=source_dir)

    width, height = (round(mm * args.ppi / 25.4) for mm in (120, 44))
    probe = output / "surface_probe.typ"
    probe.write_text('''#import "../../fiziko.typ": canvas, sphere-stipple-rings, tube
#let method = sys.inputs.at("method")
#let scale = float(sys.inputs.at("scale"))
#let density = float(sys.inputs.at("density"))
#let seed = int(sys.inputs.at("seed"))
#let path = ((60 + (89 - 103) * scale, 22 + (33 - 22) * scale),
  (60 + (103 - 103) * scale, 22 + (10 - 22) * scale),
  (60 + (115 - 103) * scale, 22 + (28 - 22) * scale))
#set page(width: 120mm, height: 44mm, margin: 0pt)
#canvas(120, 44, if method == "sphere" {
  sphere-stipple-rings(22 * scale, center: (70,22), seed: seed, density: density)
} else {
  tube(path, 3 * scale, hatch: "s", per: 48, seed: seed, dot-density: density)
})
''')

    rows = []
    for method, densities in (("sphere", [0.45, 0.55, 0.65]),
                              ("tube", [0.46, 0.56, 0.66])):
        for index, scale in enumerate(SCALES):
            figure = 601 + index if method == "sphere" else 611 + index
            directory = output / f"{method}-scale-{scale:g}"
            directory.mkdir(exist_ok=True)
            reference = directory / "source.png"
            raster(source_dir / f"{driver.stem}-{figure}.pdf", reference,
                   args.ppi, (width, height), directory)
            source_pixels = region(gray(reference), (width, height), args.ppi, rect(method, scale))
            for seed in seeds:
                for density in densities:
                    stem = f"seed-{seed}-density-{density:g}"
                    pdf, png = directory / f"{stem}.pdf", directory / f"{stem}.png"
                    run(["typst", "compile", "--ignore-system-fonts", "--root", str(ROOT),
                         str(probe), str(pdf), "--input", f"method={method}",
                         "--input", f"scale={scale}", "--input", f"density={density}",
                         "--input", f"seed={seed}"])
                    raster(pdf, png, args.ppi, (width, height), directory)
                    native = region(gray(png), (width, height), args.ppi, rect(method, scale))
                    scores = metrics(source_pixels, native)
                    rows.append({"method": method, "scale": scale, "seed": seed,
                                 "density": density, "metrics": scores})
                    print(f"{method} {scale:g}x seed={seed} density={density:g}: "
                          f"ROI RMSE {scores['rmse']:.5f}, dark {scores['dark_ratio']:.3f}, "
                          f"ink {scores['ink_ratio']:.3f}", flush=True)

    report = output / "results.json"
    report.write_text(json.dumps({"ppi": args.ppi, "seeds": seeds, "results": rows}, indent=2) + "\n")
    print(f"Report: {report}")


if __name__ == "__main__":
    main()
