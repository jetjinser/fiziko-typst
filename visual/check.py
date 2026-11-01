"""Render fixed Typst cases and compare exact decoded PNG pixels."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from compare import compare


ROOT = Path(__file__).resolve().parent.parent
CORE_CASES = (
    "brush", "sphere-concentric", "sphere-latitude", "tube-longitudinal",
    "tube-variable", "tube-transverse", "stipple-brush", "stipple-sphere",
    "stipple-field", "stipple-tube",
)
CASES = ("figure-11-page-5",) + CORE_CASES


def render_command(case, actual):
    args = ["typst", "compile", "--root", str(ROOT), "--ignore-system-fonts"]
    if case == "figure-11-page-5":
        return args + [str(ROOT / "main.typ"), str(actual), "--ppi", "130", "--pages", "5"]
    return args + [str(ROOT / "visual/core.typ"), str(actual), "--ppi", "200",
                   "--input", f"case={case}"]


def run_case(case, output, env, update=False):
    directory = output / case
    # Only clear this known case's old reports, never an arbitrary output tree.
    directory.mkdir(parents=True, exist_ok=True)
    for name in ("actual.png", "diff.png", "comparison.png", "comparison.json", "render.log"):
        (directory / name).unlink(missing_ok=True)
    actual = directory / "actual.png"
    reference = ROOT / "visual" / f"{case}.png"
    started = time.monotonic()
    result = subprocess.run(render_command(case, actual), cwd=ROOT, env=env,
                            capture_output=True, text=True)
    (directory / "render.log").write_text(result.stdout + result.stderr)
    report = {"case": case, "seconds": round(time.monotonic() - started, 2)}
    if result.returncode:
        return report | {"status": "render-error", "detail": result.stderr.strip()}
    if reference.exists():
        report |= compare(reference, actual, directory)
    else:
        report |= {"matched": False, "detail": "Missing reference"}
    if update:
        shutil.copyfile(actual, reference)
        return report | {"status": "updated"}
    return report | {"status": "pass" if report["matched"] else "fail"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", action="append", choices=CASES,
                        help="Run one case (repeatable); default: all cases")
    parser.add_argument("--update", action="store_true",
                        help="Replace explicitly selected references after visual review")
    parser.add_argument("--output", type=Path, default=ROOT / "build/visual")
    args = parser.parse_args()
    if args.update and not args.case:
        parser.error("--update requires explicit --case selections")
    for tool in ("typst", "magick"):
        if not shutil.which(tool):
            parser.error(f"{tool} is missing; enter the project's Nix devshell")
    version = subprocess.check_output(["typst", "--version"], text=True).strip()
    if version.split()[:2] != ["typst", "0.15.1"]:
        parser.error(f"baselines require Typst 0.15.1; found {version}")
    font_path = os.environ.get("FIZIKO_TEST_FONT_PATH")
    if not font_path or not all(Path(p).is_dir() for p in font_path.split(os.pathsep)):
        parser.error("FIZIKO_TEST_FONT_PATH is missing or invalid; enter the project's Nix devshell")
    env = dict(os.environ, TYPST_FONT_PATHS=font_path)
    # Ignore caller options that could disable the fonts embedded in Typst.
    env.pop("TYPST_IGNORE_EMBEDDED_FONTS", None)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    reports = []
    for case in dict.fromkeys(args.case or CASES):
        try:
            report = run_case(case, output, env, args.update)
        except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as error:
            report = {"case": case, "status": "error", "detail": str(error)}
        reports.append(report)
        print(f"{report['status'].upper()}: {case}", flush=True)
        if "detail" in report:
            print(report["detail"], flush=True)
    summary = {"typst": version, "font_path": font_path, "cases": reports}
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Reports: {output}", flush=True)
    return int(any(r["status"] not in ("pass", "updated") for r in reports))


if __name__ == "__main__":
    sys.exit(main())
