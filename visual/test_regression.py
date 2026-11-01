"""Exercise the image gate and baseline-update rules with small real PNGs."""

import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import check
from compare import compare


class ImageGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.reference = self.root / "reference.png"
        self.actual = self.root / "actual.png"
        self.output = self.root / "report"
        subprocess.run(["magick", "-size", "8x8", "xc:white", str(self.reference)], check=True)

    def test_metadata_changes_do_not_fail(self):
        subprocess.run(["magick", str(self.reference), "-set", "comment", "different metadata",
                        str(self.actual)], check=True)
        self.assertNotEqual(self.reference.read_bytes(), self.actual.read_bytes())
        self.assertTrue(compare(self.reference, self.actual, self.output)["matched"])

    def test_one_pixel_change_fails_and_keeps_review_images(self):
        subprocess.run(["magick", str(self.reference), "-fill", "black", "-draw", "point 3,4",
                        str(self.actual)], check=True)
        self.assertFalse(compare(self.reference, self.actual, self.output)["matched"])
        self.assertTrue((self.output / "diff.png").is_file())
        self.assertTrue((self.output / "comparison.png").is_file())
        self.assertFalse(json.loads((self.output / "comparison.json").read_text())["matched"])

    def test_dimension_change_fails_even_for_white_images(self):
        subprocess.run(["magick", "-size", "9x8", "xc:white", str(self.actual)], check=True)
        self.assertFalse(compare(self.reference, self.actual, self.output)["matched"])

    def test_bad_png_is_an_error(self):
        self.actual.write_text("not an image")
        with self.assertRaises(ValueError):
            compare(self.reference, self.actual, self.output)

    def test_renderer_failure_does_not_update_reference(self):
        (self.root / "visual").mkdir()
        baseline = self.root / "visual/brush.png"
        baseline.write_bytes(self.reference.read_bytes())
        original = baseline.read_bytes()
        with patch.object(check, "ROOT", self.root), patch.object(
            check, "render_command", return_value=["magick", "nonexistent-input.png", str(self.actual)]
        ):
            report = check.run_case("brush", self.output, os.environ.copy(), update=True)
        self.assertEqual(report["status"], "render-error")
        self.assertEqual(baseline.read_bytes(), original)

    def test_missing_reference_fails_without_creating_one(self):
        (self.root / "visual").mkdir()
        output_image = self.output / "brush/actual.png"
        with patch.object(check, "ROOT", self.root), patch.object(
            check, "render_command", return_value=["magick", str(self.reference), str(output_image)]
        ):
            report = check.run_case("brush", self.output, os.environ.copy())
        self.assertEqual(report["status"], "fail")
        self.assertFalse((self.root / "visual/brush.png").exists())

    def test_update_requires_explicit_cases(self):
        with patch("sys.argv", ["check.py", "--update"]), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                check.main()
        self.assertEqual(error.exception.code, 2)

    def test_explicit_update_creates_selected_reference(self):
        (self.root / "visual").mkdir()
        output_image = self.output / "brush/actual.png"
        with patch.object(check, "ROOT", self.root), patch.object(
            check, "render_command", return_value=["magick", str(self.reference), str(output_image)]
        ):
            report = check.run_case("brush", self.output, os.environ.copy(), update=True)
        self.assertEqual(report["status"], "updated")
        self.assertEqual((self.root / "visual/brush.png").read_bytes(), output_image.read_bytes())

    def test_case_reports_are_collected_after_a_failure(self):
        # A failure in one family must not hide the status of later families.
        argv = ["check.py", "--case", "brush", "--case", "stipple-tube",
                "--output", str(self.output)]
        reports = [{"case": "brush", "status": "fail"},
                   {"case": "stipple-tube", "status": "pass"}]
        with patch("sys.argv", argv), patch.dict(os.environ, {"FIZIKO_TEST_FONT_PATH": str(self.root)}), \
             patch.object(check.shutil, "which", return_value="tool"), \
             patch.object(check.subprocess, "check_output", return_value="typst 0.15.1 (test)"), \
             patch.object(check, "run_case", side_effect=reports), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check.main(), 1)
        self.assertEqual(json.loads((self.output / "summary.json").read_text())["cases"], reports)


if __name__ == "__main__":
    unittest.main()
