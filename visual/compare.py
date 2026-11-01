"""Compare decoded PNG pixels and retain review images; requires ImageMagick 7."""

import argparse
import json
from pathlib import Path
import struct
import subprocess


def png_size(path):
    with Path(path).open("rb") as stream:
        header = stream.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


def compare(reference, actual, output):
    """Exact decoded-pixel gate; PNG metadata and compression do not matter."""
    reference, actual, output = map(Path, (reference, actual, output))
    output.mkdir(parents=True, exist_ok=True)
    reference_size, actual_size = png_size(reference), png_size(actual)
    # ImageMagick may pad unequal dimensions; size changes must always fail.
    result = subprocess.run(
        ["magick", "compare", "-metric", "AE", "-fuzz", "0",
         str(reference), str(actual), "null:"],
        capture_output=True, text=True,
    )
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr.strip())
    matched = result.returncode == 0 and reference_size == actual_size
    report = {
        "matched": matched,
        "reference_size": reference_size,
        "actual_size": actual_size,
        "absolute_error": result.stderr.strip(),
    }
    if not matched:
        diff = output / "diff.png"
        subprocess.run(
            ["magick", "compare", "-highlight-color", "red",
             "-lowlight-color", "white", str(reference), str(actual), str(diff)],
            check=False, capture_output=True,
        )
        # Preserve reference / actual / highlighted difference, left to right.
        subprocess.run(
            ["magick", str(reference), str(actual), str(diff),
             "-background", "white", "+append", str(output / "comparison.png")],
            check=True, capture_output=True,
        )
    (output / "comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference", type=Path)
    parser.add_argument("actual", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    report = compare(args.reference, args.actual, args.output)
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if report["matched"] else 1)
