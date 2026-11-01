"""Compare transverse tube dash period across keyed seeds at the fixed M7 plate."""

import argparse
import json
import math
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]


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


def measure(source, native):
    source_dark = sum(v < 128 for v in source) / len(source)
    native_dark = sum(v < 128 for v in native) / len(native)
    source_ink = sum(255 - v for v in source) / (255 * len(source))
    native_ink = sum(255 - v for v in native) / (255 * len(native))
    rmse = math.sqrt(sum((a-b)**2 for a, b in zip(source, native)) / len(source)) / 255
    return {"rmse": rmse, "dark_ratio": native_dark / source_dark,
            "ink_ratio": native_ink / source_ink}


def crop(pixels, size, ppi):
    width, _ = size
    left, top, right, bottom = (round(mm * ppi / 25.4) for mm in (4, 7, 106, 36))
    return b"".join(pixels[y * width + left:y * width + right]
                    for y in range(top, bottom))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ppi", type=int, default=600)
    parser.add_argument("--seed", type=int, action="append", dest="seeds")
    parser.add_argument("--period", type=float, action="append", dest="periods")
    parser.add_argument("--output", type=Path, default=ROOT / "build/stage4-dash-scan")
    args = parser.parse_args()
    seeds, periods = args.seeds or [1, 2, 3, 5], args.periods or [0.75, 0.9, 1.05, 1.2]
    if not 72 <= args.ppi <= 1200 or any(seed < 0 for seed in seeds) or any(p <= 0 for p in periods):
        parser.error("ppi must be [72, 1200], seeds nonnegative, periods positive")
    upstream = os.environ.get("FIZIKO_UPSTREAM_PATH")
    if not upstream:
        parser.error("Use nix develop path:./nix")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    driver = output / "transverse_probe.mp"
    driver.write_text(f'''input "{Path(upstream) / "fiziko.mp"}";
numeric scale, figw, figh;
vardef P(expr x,y) = (x*mm,(figh-y)*mm) enddef;
beginfig(701);
  scale:=1; figw:=110; figh:=42; randomseed:=1;
  draw tube.t(P(6,32)..P(40,14)..P(74,32)..P(104,16))(5mm);
  setbounds currentpicture to (0,0)--(110mm,0)--(110mm,42mm)--(0,42mm)--cycle;
endfig;
end.
''')
    source_dir = output / "source"
    source_dir.mkdir(exist_ok=True)
    run(["mpost", "-interaction=nonstopmode", "-halt-on-error", str(driver)], cwd=source_dir)
    run(["mptopdf", f"{driver.stem}.701"], cwd=source_dir)
    size = tuple(round(mm * args.ppi / 25.4) for mm in (110, 42))
    source_png = output / "source.png"
    raster(source_dir / f"{driver.stem}-701.pdf", source_png, args.ppi, size, output)
    reference = crop(gray(source_png), size, args.ppi)
    probe = output / "transverse_probe.typ"
    probe.write_text('''#import "../../fiziko.typ": canvas, tube
#let seed = int(sys.inputs.at("seed"))
#let period = float(sys.inputs.at("period"))
#set page(width: 110mm, height: 42mm, margin: 0pt)
#canvas(110, 42, tube(((6,32),(40,14),(74,32),(104,16)), 5,
  hatch: "t", per: 384, period: period * 0.3514598, seed: seed))
''')
    rows = []
    for seed in seeds:
        for period in periods:
            stem = f"seed-{seed}-period-{period:g}"
            directory = output / stem
            directory.mkdir(exist_ok=True)
            pdf, png = directory / "native.pdf", directory / "native.png"
            run(["typst", "compile", "--ignore-system-fonts", "--root", str(ROOT),
                 str(probe), str(pdf), "--input", f"seed={seed}",
                 "--input", f"period={period}"])
            raster(pdf, png, args.ppi, size, directory)
            scores = measure(reference, crop(gray(png), size, args.ppi))
            rows.append({"seed": seed, "period_tex_pt": period, "metrics": scores})
            print(f"seed={seed} period={period:g}pt: ROI RMSE {scores['rmse']:.6f}, "
                  f"dark {scores['dark_ratio']:.3f}, ink {scores['ink_ratio']:.3f}", flush=True)
    report = output / "results.json"
    report.write_text(json.dumps({"ppi": args.ppi, "seeds": seeds,
                                  "periods_tex_pt": periods, "results": rows}, indent=2) + "\n")
    print(f"Report: {report}")


if __name__ == "__main__":
    main()
