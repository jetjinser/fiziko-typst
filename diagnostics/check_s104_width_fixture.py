#!/usr/bin/env python3
"""Check the source-fixed S104 callback sample against MetaPost's trace."""

import json
import subprocess


def main() -> None:
    result = subprocess.run(
        [
            "typst", "eval",
            "query(<s104-width-sample>).first().value",
            "--in", "diagnostics/s104_width_fraction_fixture.typ",
            "--root", ".",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    actual = json.loads(result.stdout)
    expected = {"time-fixed": 39321, "width-fixed": 8744}
    if actual != expected:
        raise SystemExit(f"S104 callback sample differs: {actual} != {expected}")
    print("S104 callback sample: source time and width match exactly")


if __name__ == "__main__":
    main()
