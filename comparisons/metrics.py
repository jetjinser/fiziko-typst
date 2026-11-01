"""Descriptive same-grid grayscale metrics, with explicit physical crops."""

from collections import Counter
import math
from pathlib import Path
import struct
import subprocess


def read_gray(path, expected_size):
    with Path(path).open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"Not a PNG: {path}")
    size = struct.unpack(">II", header[16:24])
    if size != tuple(expected_size):
        raise ValueError(f"Unexpected raster dimensions for {path}: {size}, expected {expected_size}")
    result = subprocess.run(["magick", str(path), "-depth", "8", "gray:-"],
                            capture_output=True, check=True)
    if len(result.stdout) != size[0] * size[1]:
        raise ValueError(f"Expected one 8-bit gray channel in {path}")
    return result.stdout


def rectangle_pixels(rectangle, ppi, image_size):
    x, y, width, height = rectangle
    left, top, right, bottom = (round(value * ppi / 25.4)
                                for value in (x, y, x + width, y + height))
    if not (0 <= left < right <= image_size[0] and 0 <= top < bottom <= image_size[1]):
        raise ValueError(f"Crop is empty or outside the raster: {rectangle}")
    return left, top, right, bottom


def crop(data, image_size, rectangle):
    left, top, right, bottom = rectangle
    stride = image_size[0]
    return b"".join(data[y * stride + left:y * stride + right] for y in range(top, bottom))


def coverage(data, threshold):
    histogram = Counter(data)
    return {
        "dark": sum(count for value, count in histogram.items() if value < threshold) / len(data),
        "ink": sum((255 - value) * count for value, count in histogram.items()) / (255 * len(data)),
    }


def measure(reference, candidate, threshold=128):
    if not reference or len(reference) != len(candidate):
        raise ValueError("Metrics require equal, nonempty pixel arrays")
    if not 1 <= threshold <= 255:
        raise ValueError("Dark threshold must be in [1, 255]")
    source = coverage(reference, threshold)
    native = coverage(candidate, threshold)
    return {
        "pixels": len(reference),
        "rmse": math.sqrt(sum((a - b) ** 2 for a, b in zip(reference, candidate)) / len(reference)) / 255,
        "source_dark_coverage": source["dark"],
        "typst_dark_coverage": native["dark"],
        "source_ink_coverage": source["ink"],
        "typst_ink_coverage": native["ink"],
        "dark_coverage_ratio": native["dark"] / source["dark"] if source["dark"] else None,
    }
