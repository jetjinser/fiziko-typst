"""Validate metric semantics, crop coordinates and failure/provenance handling."""

import contextlib
import hashlib
import io
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from metrics import crop, measure, read_gray, rectangle_pixels
import run


class MetricsTests(unittest.TestCase):
    def test_identical_arrays_have_zero_rmse(self):
        metrics = measure(bytes([0, 127, 128, 255]), bytes([0, 127, 128, 255]))
        self.assertEqual(metrics["rmse"], 0)
        self.assertEqual(metrics["source_dark_coverage"], 0.5)
        self.assertEqual(metrics["dark_coverage_ratio"], 1)

    def test_known_rmse_and_coverage(self):
        metrics = measure(bytes([0, 255]), bytes([255, 255]))
        self.assertAlmostEqual(metrics["rmse"], math.sqrt(0.5))
        self.assertEqual(metrics["source_ink_coverage"], 0.5)
        self.assertEqual(metrics["typst_ink_coverage"], 0)
        self.assertEqual(metrics["dark_coverage_ratio"], 0)

    def test_grayscale_ink_is_not_binary_coverage(self):
        metrics = measure(bytes([128, 255]), bytes([128, 255]))
        self.assertEqual(metrics["source_dark_coverage"], 0)
        self.assertIsNone(metrics["dark_coverage_ratio"])
        self.assertAlmostEqual(metrics["source_ink_coverage"], 127 / 510)

    def test_invalid_arrays_and_thresholds_fail(self):
        for a, b, threshold in [(b"", b"", 128), (b"a", b"ab", 128), (b"a", b"a", 0)]:
            with self.subTest(a=a, b=b, threshold=threshold), self.assertRaises(ValueError):
                measure(a, b, threshold)

    def test_crop_preserves_row_stride_and_origin(self):
        self.assertEqual(crop(bytes(range(12)), (4, 3), (1, 1, 3, 3)), bytes([5, 6, 9, 10]))

    def test_mm_crop_uses_physical_grid_without_fitting(self):
        self.assertEqual(rectangle_pixels((1, 2, 3, 2), 254, (100, 100)), (10, 20, 40, 40))
        for rectangle in [(-1, 0, 1, 1), (0, 0, 20, 1), (0, 0, 0.001, 1)]:
            with self.subTest(rectangle=rectangle), self.assertRaises(ValueError):
                rectangle_pixels(rectangle, 254, (100, 100))

    def test_raster_dimensions_are_checked_before_metrics(self):
        with tempfile.TemporaryDirectory() as temp:
            image = Path(temp) / "image.png"
            subprocess.run(["magick", "-size", "4x2", "xc:white", str(image)], check=True)
            self.assertEqual(read_gray(image, (4, 2)), bytes([255] * 8))
            with self.assertRaises(ValueError):
                read_gray(image, (2, 4))  # Same byte count, different shape.

    def test_truncated_png_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            image = Path(temp) / "bad.png"
            image.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\0\0\0\rIHDR")
            with self.assertRaises(ValueError):
                read_gray(image, (4, 2))


class PipelineTests(unittest.TestCase):
    def test_command_failure_and_timeout_retain_command_records(self):
        outcomes = [subprocess.CompletedProcess(["tool"], 7), subprocess.TimeoutExpired(["tool"], 600)]
        for outcome in outcomes:
            with self.subTest(outcome=outcome), tempfile.TemporaryDirectory() as temp:
                directory = Path(temp)
                commands = []
                options = {"side_effect": outcome} if isinstance(outcome, Exception) else {"return_value": outcome}
                with patch.object(run.subprocess, "run", **options), self.assertRaises(RuntimeError):
                    run.invoke(["tool"], directory, os.environ.copy(), directory / "tool.log", commands)
                self.assertEqual(len(commands), 1)
                self.assertIn("seconds", commands[0])
                self.assertTrue((directory / "tool.log").is_file())

    def test_upstream_checksum_must_match(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "fiziko.mp").write_text("source")
            (root / "LICENSE.md").write_text("license")
            spec = {"file": "fiziko.mp", "license_file": "LICENSE.md",
                    "source_sha256": hashlib.sha256(b"source").hexdigest()}
            self.assertEqual(run.upstream_files(spec, root)[0], root / "fiziko.mp")
            (root / "fiziko.mp").write_text("modified source")
            with self.assertRaises(ValueError):
                run.upstream_files(spec, root)

    def test_source_and_typst_raster_flags_are_identical(self):
        a = run.raster_command(Path("source.pdf"), Path("source.png"), 600, (2598, 1228))
        b = run.raster_command(Path("typst.pdf"), Path("typst.png"), 600, (2598, 1228))
        self.assertEqual(a[:-3], b[:-3])
        self.assertNotIn("-dPDFFitPage", a)

    def test_reference_only_plate_cannot_be_claimed_as_a_pair(self):
        with patch("sys.argv", ["run.py", "--case", "M8"]), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                run.main()
        self.assertEqual(error.exception.code, 2)

    def test_failure_keeps_provenance_and_later_cases_still_run(self):
        manifest = run.load_manifest()
        lock_path = run.ROOT / "nix/flake.lock"
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "nix").mkdir()
            shutil.copyfile(lock_path, root / "nix/flake.lock")
            (root / "fiziko.mp").write_text("test source")
            (root / "LICENSE.md").write_text("test license")
            output = root / "output"

            def render(key, case, modes, directory, *args):
                if key == "M1":
                    raise RuntimeError("deliberate source failure")
                return [{"case": key, "title": "next case", "mode": "source-only", "status": "ok",
                         "frame_mm": [110,52], "source_pdf": str(directory / "reference.pdf"),
                         "source_png": str(directory / "reference.png")}]

            argv = ["run.py", "--case", "M1", "--case", "M2", "--output", str(output)]
            with patch("sys.argv", argv), patch.object(run, "ROOT", root), \
                 patch.object(run, "INPUTS", ("nix/flake.lock",)), \
                 patch.object(run, "load_manifest", return_value=manifest), \
                 patch.object(run, "environment", return_value=({}, (root / "fiziko.mp", root / "LICENSE.md"), str(root))), \
                 patch.object(run, "compare_case", side_effect=render), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(run.main(), 1)
            summary = json.loads((output / "summary.json").read_text())
            self.assertEqual([r["status"] for r in summary["results"]], ["error", "ok"])
            self.assertIn("nix/flake.lock", summary["input_sha256"])
            snapshot = Path(summary["run_directory"]) / "inputs/nix/flake.lock"
            self.assertEqual(run.sha256(snapshot), summary["input_sha256"]["nix/flake.lock"])
            self.assertTrue((output / "index.html").is_file())
            self.assertTrue((Path(summary["run_directory"]) / "summary.json").is_file())


if __name__ == "__main__":
    unittest.main()
