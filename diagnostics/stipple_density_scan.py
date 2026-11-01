"""Scan native stipple density over brush scales and keyed RNG seeds.

Run inside the locked Nix devshell. All intermediates and the JSON report are
written under build/stage4-brush-scan by default.
"""

import argparse
import json
import math
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
SCALES = {0.5: 501, 1.0: 502, 2.0: 503}


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


def brush_region(pixels, size, scale, ppi):
    width, height = size
    x0 = round((60 - 21.5 * scale) * ppi / 25.4)
    x1 = round((60 + 21.5 * scale) * ppi / 25.4)
    y0 = round((22 - 11 * scale) * ppi / 25.4)
    y1 = round((22 + 11 * scale) * ppi / 25.4)
    return b"".join(pixels[y * width + x0:y * width + x1]
                    for y in range(max(0, y0), min(height, y1)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ppi", type=int, default=300)
    parser.add_argument("--seed", type=int, action="append", dest="seeds")
    parser.add_argument("--density", type=float, action="append", dest="densities")
    parser.add_argument("--output", type=Path, default=ROOT / "build/stage4-brush-scan")
    args = parser.parse_args()
    seeds = args.seeds or [1, 2, 3, 5, 8]
    densities = args.densities or [0.3, 0.4, 0.5, 0.6, 0.7]
    if not 72 <= args.ppi <= 1200 or any(seed < 0 for seed in seeds):
        parser.error("ppi must be [72, 1200] and seeds nonnegative")
    if any(not 0 < density <= 2 for density in densities):
        parser.error("densities must be in (0, 2]")

    upstream = os.environ.get("FIZIKO_UPSTREAM_PATH")
    if not upstream:
        parser.error("Use nix develop path:./nix")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source = output / "instrumented-fiziko.mp"
    run(["python3", str(ROOT / "diagnostics/instrument_brush.py"),
         str(Path(upstream) / "fiziko.mp"), str(source)], stdout=None)

    driver = (ROOT / "diagnostics/brush_scale_probe.mp").read_text()
    driver = driver.replace('input "/tmp/fiziko-s101-stipple-trace.mp";',
                             f'input "{source}";')
    source_driver = output / "brush_scale_probe.mp"
    source_driver.write_text(driver)
    source_dir = output / "source"
    source_dir.mkdir(exist_ok=True)
    run(["mpost", "-interaction=nonstopmode", "-halt-on-error", str(source_driver)], cwd=source_dir)
    for figure in SCALES.values():
        run(["mptopdf", f"{source_driver.stem}.{figure}"], cwd=source_dir)

    width, height = (round(mm * args.ppi / 25.4) for mm in (120, 44))
    probe = output / "brush_probe.typ"
    probe.write_text('''#import "../../fiziko.typ": canvas, stroke-stipple-brush, pt
#let scale = float(sys.inputs.at("scale"))
#let density = float(sys.inputs.at("density"))
#let seed = int(sys.inputs.at("seed"))
#let point(x, y) = (60 + (x - 26.5) * scale, 22 + (y - 24) * scale)
#set page(width: 120mm, height: 44mm, margin: 0pt)
#canvas(120, 44, stroke-stipple-brush((point(5, 35), point(26, 13), point(48, 32)),
  t => 0.3 * pt * calc.sin(calc.pi * t), closed: false, per: 48, density: density, seed: seed))
''')

    rows = []
    for scale, figure in SCALES.items():
        directory = output / f"scale-{scale:g}"
        directory.mkdir(exist_ok=True)
        reference = directory / "source.png"
        raster(source_dir / f"{source_driver.stem}-{figure}.pdf", reference,
               args.ppi, (width, height), directory)
        source_pixels = gray(reference)
        for seed in seeds:
            for density in densities:
                stem = f"seed-{seed}-density-{density:g}"
                pdf, png = directory / f"{stem}.pdf", directory / f"{stem}.png"
                run(["typst", "compile", "--ignore-system-fonts", "--root", str(ROOT),
                     str(probe), str(pdf), "--input", f"scale={scale}",
                     "--input", f"density={density}", "--input", f"seed={seed}"])
                raster(pdf, png, args.ppi, (width, height), directory)
                native_pixels = gray(png)
                rows.append({"scale": scale, "seed": seed, "density": density,
                             "full_frame": metrics(source_pixels, native_pixels),
                             "brush_region": metrics(brush_region(source_pixels, (width, height), scale, args.ppi),
                                                     brush_region(native_pixels, (width, height), scale, args.ppi))})
                print(f"{scale:g}x seed={seed} density={density:g}: "
                      f"ROI RMSE {rows[-1]['brush_region']['rmse']:.5f}, "
                      f"dark {rows[-1]['brush_region']['dark_ratio']:.3f}, "
                      f"ink {rows[-1]['brush_region']['ink_ratio']:.3f}", flush=True)

    result = {"ppi": args.ppi, "seeds": seeds, "densities": densities, "results": rows}
    report = output / "results.json"
    report.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Report: {report}")


if __name__ == "__main__":
    main()
