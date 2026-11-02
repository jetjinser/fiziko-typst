"""Build pinned upstream/Typst plates on one Ghostscript raster grid."""

import argparse
import hashlib
from html import escape
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time

from metrics import crop, measure, read_gray, rectangle_pixels


ROOT = Path(__file__).resolve().parent.parent
MODES = ("nominal", "calibrated")
INPUTS = (
    "fiziko.typ", "contour.typ", "solve.typ", "nix/flake.nix", "nix/flake.lock",
    "comparisons/manifest.json", "comparisons/plates.typ", "comparisons/run.py",
    "comparisons/metrics.py", "comparisons/globe-coasts.typ",
    "comparisons/m4-tube-path.typ",
    "comparisons/m11-knot-paths.typ",
    "comparisons/extract-globe-coasts.py", "comparisons/reference/main.mp",
    "comparisons/reference/supplemental.mp", "comparisons/reference/isolated.mp",
)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_manifest():
    manifest = json.loads((ROOT / "comparisons/manifest.json").read_text())
    if manifest["schema_version"] != 1:
        raise ValueError("Unsupported comparison manifest schema")
    cases = manifest["source_only_cases"] | manifest["cases"]
    for key, case in cases.items():
        if not re.fullmatch(r"[A-Z]+[0-9]+", key):
            raise ValueError(f"Invalid case name: {key}")
        if case["driver"] not in ("main.mp", "supplemental.mp", "isolated.mp"):
            raise ValueError(f"Invalid source driver: {key}")
        if not isinstance(case["figure"], int) or case["figure"] <= 0:
            raise ValueError(f"Invalid source figure: {key}")
        if len(case["frame_mm"]) != 2 or any(not math.isfinite(v) or v <= 0 for v in case["frame_mm"]):
            raise ValueError(f"Invalid frame: {key}")
        for rectangle in case.get("regions_mm", {}).values():
            x, y, w, h = rectangle
            if not (0 <= x < x+w <= case["frame_mm"][0] and 0 <= y < y+h <= case["frame_mm"][1]):
                raise ValueError(f"Invalid physical crop: {key}")
        if key in manifest["cases"]:
            for mode in MODES:
                if any(isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v)
                       for v in case[mode].values()):
                    raise ValueError(f"Non-numeric drawing input: {key}/{mode}")
    lock = json.loads((ROOT / "nix/flake.lock").read_text())
    if lock["nodes"]["fiziko-upstream"]["locked"]["rev"] != manifest["upstream"]["revision"]:
        raise ValueError("Manifest and Nix disagree about the upstream revision")
    return manifest


def upstream_files(spec, directory):
    source = directory / spec["file"]
    license_file = directory / spec["license_file"]
    if sha256(source) != spec["source_sha256"]:
        raise ValueError("Upstream fiziko.mp checksum does not match the pinned source")
    if not license_file.is_file():
        raise ValueError("Pinned upstream license file is missing")
    return source, license_file


def invoke(command, cwd, env, log, commands):
    started = time.monotonic()
    record = {"argv": list(map(str, command)), "cwd": str(cwd),
              "returncode": None, "log": str(log)}
    commands.append(record)
    try:
        with log.open("w") as stream:
            result = subprocess.run(command, cwd=cwd, env=env, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=600)
        record["returncode"] = result.returncode
    except (OSError, subprocess.TimeoutExpired) as error:
        record["error"] = str(error)
        raise RuntimeError(f"{command[0]} could not complete; see {log}: {error}") from error
    finally:
        record["seconds"] = round(time.monotonic() - started, 3)
    if result.returncode:
        raise RuntimeError(f"{command[0]} exited {result.returncode}; see {log}")


def raster_command(pdf, png, ppi, size):
    # Fixed pixel grid at the declared physical scale. No fitting, scaling,
    # registration or renderer-specific PNG path is used on either side.
    return ["gs", "-q", "-dSAFER", "-dBATCH", "-dNOPAUSE", "-dPDFSTOPONERROR",
            "-sDEVICE=pnggray", f"-r{ppi}", f"-g{size[0]}x{size[1]}",
            "-dFIXEDMEDIA", "-dGraphicsAlphaBits=4", "-dTextAlphaBits=4",
            f"-sOutputFile={png}", "-f", str(pdf)]


def render_source(case, directory, snapshot, env, commands, ppi):
    directory.mkdir(parents=True)
    driver = snapshot / "comparisons/reference" / case["driver"]
    (directory / "source.mp").write_text(f'selected := {case["figure"]};\ninput "{driver}";\n')
    invoke(["mpost", "-interaction=nonstopmode", "-halt-on-error", "source.mp"],
           directory, env, directory / "mpost.stdout", commands)
    invoke(["mptopdf", f'source.{case["figure"]}'], directory, env,
           directory / "mptopdf.stdout", commands)
    pdf = directory / "reference.pdf"
    shutil.copyfile(directory / f'source-{case["figure"]}.pdf', pdf)
    png = directory / "reference.png"
    size = tuple(round(v * ppi / 25.4) for v in case["frame_mm"])
    invoke(raster_command(pdf, png, ppi, size), directory, env, directory / "gs.log", commands)
    # A source-only build also validates that the expected single page exists.
    pixels = read_gray(png, size)
    return pdf, png, size, pixels


def render_native(key, case, mode, directory, snapshot, env, commands, ppi, size):
    directory.mkdir(parents=True)
    pdf, png = directory / "typst.pdf", directory / "typst.png"
    command = ["typst", "compile", "--ignore-system-fonts", "--root", str(snapshot),
               str(snapshot / "comparisons/plates.typ"), str(pdf), "--input", f"case={key}"]
    params = case[mode] | dict(zip(("width", "height"), case["frame_mm"]))
    for name, value in params.items():
        command += ["--input", f"{name}={value}"]
    invoke(command, directory, env, directory / "typst.log", commands)
    invoke(raster_command(pdf, png, ppi, size), directory, env, directory / "gs.log", commands)
    return png


def artifacts(reference, candidate, directory, gain, env, commands):
    difference = directory / "difference.png"
    invoke(["magick", str(reference), str(candidate), "-compose", "difference", "-composite",
            "-evaluate", "Multiply", str(gain), str(difference)], directory, env,
           directory / "difference.log", commands)
    comparison = directory / "comparison.png"
    invoke(["magick", str(reference), str(candidate), str(difference), "+append", str(comparison)],
           directory, env, directory / "comparison.log", commands)


def compare_case(key, case, modes, directory, snapshot, env, commands, render, source_only=False):
    ppi = render["ppi"]
    _, reference, size, source = render_source(case, directory / "source", snapshot, env, commands, ppi)
    base = {"case": key, "title": case["title"], "frame_mm": case["frame_mm"], "size_px": size,
            "source_png": str(reference), "source_pdf": str(directory / "source/reference.pdf"),
            "source_pixels_sha256": hashlib.sha256(source).hexdigest()}
    if source_only:
        return [base | {"mode": "source-only", "status": "ok"}]
    results = []
    rendered = {}
    for mode in modes:
        try:
            target = directory / mode
            cache_key = json.dumps(case[mode], sort_keys=True)
            if cache_key in rendered:
                target.mkdir()
                previous = rendered[cache_key]
                for name in ("typst.pdf", "typst.png"):
                    shutil.copyfile(previous / name, target / name)
                candidate = target / "typst.png"
            else:
                previous = None
                candidate = render_native(key, case, mode, target, snapshot, env, commands, ppi, size)
                rendered[cache_key] = target
            native = read_gray(candidate, size)
            regions = {"full": measure(source, native, render["dark_threshold"])}
            for name, rectangle in case.get("regions_mm", {}).items():
                bounds = rectangle_pixels(rectangle, ppi, size)
                regions[name] = measure(crop(source, size, bounds), crop(native, size, bounds),
                                        render["dark_threshold"]) | {"rectangle_px": bounds}
            artifacts(reference, candidate, target, render["difference_gain"], env, commands)
            result = base | {"mode": mode, "status": "ok", "parameters": case[mode],
                             "shared": case["shared"], "notes": case["notes"],
                             "regions_mm": case.get("regions_mm", {}), "metrics": regions,
                             "typst_png": str(candidate), "typst_pdf": str(target / "typst.pdf"),
                             "comparison_png": str(target / "comparison.png"),
                             "difference_png": str(target / "difference.png"),
                             "typst_pixels_sha256": hashlib.sha256(native).hexdigest()}
            if previous:
                result["reused_identical_parameters_from"] = previous.name
            (target / "metrics.json").write_text(json.dumps(result, indent=2) + "\n")
            results.append(result)
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            results.append(base | {"mode": mode, "status": "error", "detail": str(error)})
    return results


def write_html(output, summary):
    def link(path):
        return escape(Path(path).relative_to(output).as_posix(), quote=True)

    parts = ["<!doctype html><html lang='en'><meta charset='utf-8'>",
             "<title>Fiziko source comparisons</title><style>",
             "body{font:16px system-ui;margin:2rem;max-width:1500px;color:#222}"
             "img{max-width:100%;border:1px solid #ddd}table{border-collapse:collapse}"
             "td,th{padding:.4rem .8rem;border:1px solid #ddd;text-align:left}"
             "pre{white-space:pre-wrap}section{margin:2rem 0}a{color:#125ca3}</style>",
             "<h1>Fiziko source comparisons</h1>",
             f"<p>Upstream {escape(summary['upstream']['revision'])}; {summary['render']['ppi']} ppi. "
             "Both sides: PDF → the same Ghostscript pnggray rasterizer. "
             "Metrics describe differences; they are not pass/fail fidelity thresholds.</p>",
             f"<p>Comparison order: upstream / Typst / absolute difference ×{summary['render']['difference_gain']}. "
             "No image alignment or fit was applied. Nominal means matching shared physical inputs; "
             "native algorithms and previously calibrated library defaults still differ.</p>",
             "<p><a href='summary.json'>Metrics and provenance JSON</a></p>"]
    for result in summary["results"]:
        parts.append(f"<section><h2>{escape(result['case'])} — {escape(result['mode'])}</h2>")
        if result["status"] != "ok":
            parts.append(f"<pre>{escape(result['detail'])}</pre></section>")
            continue
        parts.append(f"<p>{escape(result['title'])} · {result['frame_mm']} mm</p>")
        if result["mode"] == "source-only":
            parts.append(f"<a href='{link(result['source_pdf'])}'>Source PDF</a>"
                         f"<p><img src='{link(result['source_png'])}' alt='Source plate'></p></section>")
            continue
        parts.append(f"<p>{escape(result['notes'])}</p><pre>"
                     f"{escape(json.dumps(result['parameters'], sort_keys=True))}</pre>")
        parts.append("<table><tr><th>Region</th><th>RMSE [0–1]</th><th>Source dark %</th>"
                     "<th>Typst dark %</th><th>Source ink %</th><th>Typst ink %</th></tr>")
        for region, metrics in result["metrics"].items():
            parts.append(f"<tr><td>{escape(region)}</td><td>{metrics['rmse']:.6f}</td>"
                         f"<td>{100*metrics['source_dark_coverage']:.4f}</td>"
                         f"<td>{100*metrics['typst_dark_coverage']:.4f}</td>"
                         f"<td>{100*metrics['source_ink_coverage']:.4f}</td>"
                         f"<td>{100*metrics['typst_ink_coverage']:.4f}</td></tr>")
        parts.append(f"</table><p><a href='{link(result['source_pdf'])}'>Source PDF</a> · "
                     f"<a href='{link(result['typst_pdf'])}'>Typst PDF</a> · "
                     f"<a href='{link(result['source_png'])}'>Source raster</a> · "
                     f"<a href='{link(result['typst_png'])}'>Typst raster</a> · "
                     f"<a href='{link(result['difference_png'])}'>Difference</a></p>"
                     f"<img src='{link(result['comparison_png'])}' alt='Upstream, Typst and amplified difference'></section>")
    (output / "index.html").write_text("\n".join(parts) + "</html>\n")


def environment(manifest):
    for tool in ("typst", "mpost", "mptopdf", "pdftex", "gs", "magick"):
        if not shutil.which(tool):
            raise ValueError(f"Missing {tool}; use nix develop path:./nix")
    versions = {}
    for tool in ("typst", "mpost", "pdftex", "gs", "magick"):
        versions[tool] = subprocess.check_output([tool, "--version"], text=True).splitlines()[0]
    if versions["typst"].split()[:2] != ["typst", "0.15.1"]:
        raise ValueError("Use Typst 0.15.1 from the locked Nix devshell")
    upstream = os.environ.get("FIZIKO_UPSTREAM_PATH")
    font_path = os.environ.get("FIZIKO_TEST_FONT_PATH")
    if not upstream or not font_path or not all(Path(p).is_dir() for p in font_path.split(os.pathsep)):
        raise ValueError("Missing upstream/font paths; use nix develop path:./nix")
    files = upstream_files(manifest["upstream"], Path(upstream))
    return versions | {"python": sys.version.split()[0], "platform": platform.platform()}, files, font_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", action="append", help="Select a plate (repeatable); see --list")
    parser.add_argument("--mode", choices=(*MODES, "both"), default="both")
    parser.add_argument("--source-only", action="store_true", help="Build reference plates without native counterparts")
    parser.add_argument("--ppi", type=int, help="Override the 600 ppi measurement grid for a preview")
    parser.add_argument("--output", type=Path, default=ROOT / "build/comparisons")
    parser.add_argument("--list", action="store_true", help="List paired and reference-only plates without building")
    args = parser.parse_args()
    try:
        manifest = load_manifest()
        cases = manifest["cases"] | manifest["source_only_cases"]
        if args.list:
            for key, case in cases.items():
                kind = "paired" if key in manifest["cases"] else "source-only"
                print(f"{key:5} {kind:11} {case['frame_mm']} mm  {case['title']}")
            return 0
        selection = args.case or (sorted((k for k in cases if k != "C1"),
                                        key=lambda k: (k[0], int(k[1:])))
                                  if args.source_only else list(manifest["cases"]))
        selection = list(dict.fromkeys(selection))
        if any(key not in cases for key in selection):
            raise ValueError("Unknown plate; use --list")
        if not args.source_only and any(key not in manifest["cases"] for key in selection):
            raise ValueError("Some selected plates are reference-only; add --source-only")
        render = manifest["render"] | ({"ppi": args.ppi} if args.ppi is not None else {})
        if not 72 <= render["ppi"] <= 1200:
            raise ValueError("PPI must be in [72, 1200]")
        versions, files, font_path = environment(manifest)
    except (OSError, KeyError, ValueError, subprocess.SubprocessError) as error:
        parser.error(str(error))

    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="run-", dir=output))
    snapshot, upstream = work / "inputs", work / "upstream"
    upstream.mkdir()
    for path in files:
        shutil.copyfile(path, upstream / path.name)
    hashes = {}
    for name in INPUTS:
        target = snapshot / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
        hashes[name] = sha256(target)
    lock = json.loads((snapshot / "nix/flake.lock").read_text())
    epoch = str(lock["nodes"]["fiziko-upstream"]["locked"]["lastModified"])
    env = dict(os.environ, TYPST_FONT_PATHS=font_path,
               MPINPUTS=str(upstream) + os.pathsep, SOURCE_DATE_EPOCH=epoch, TZ="UTC", LC_ALL="C")
    env.pop("TYPST_IGNORE_EMBEDDED_FONTS", None)
    modes = MODES if args.mode == "both" else (args.mode,)
    summary = {"schema_version": 1, "upstream": manifest["upstream"], "render": render,
               "versions": versions, "input_sha256": hashes, "run_directory": str(work),
               "nixpkgs_revision": lock["nodes"]["nixpkgs"]["locked"]["rev"],
               "upstream_nar_hash": lock["nodes"]["fiziko-upstream"]["locked"]["narHash"],
               "source_date_epoch": epoch, "font_path": font_path, "commands": [], "results": []}
    started = time.monotonic()
    for key in selection:
        try:
            results = compare_case(key, cases[key], modes, work / key, snapshot, env,
                                   summary["commands"], render, args.source_only)
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            results = [{"case": key, "mode": "source", "status": "error", "detail": str(error)}]
        summary["results"].extend(results)
        for result in results:
            print(f"{result['status'].upper()}: {key}/{result['mode']}", flush=True)
            if result["status"] != "ok":
                print(result["detail"], flush=True)
        summary["seconds"] = round(time.monotonic() - started, 3)
        (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        write_html(output, summary)
    # Retain each run's report as well as updating the output's latest index.
    shutil.copyfile(output / "summary.json", work / "summary.json")
    print(f"Report: {output / 'index.html'}", flush=True)
    return int(any(item["status"] != "ok" for item in summary["results"]))


if __name__ == "__main__":
    sys.exit(main())
