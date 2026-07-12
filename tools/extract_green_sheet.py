from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

try:
    from .chroma_key import _normalize_canvas, _remove_green
except ImportError:
    from chroma_key import _normalize_canvas, _remove_green


def _find_boundaries(alpha: Image.Image, segments: int, axis: str) -> list[int]:
    size = alpha.width if axis == "x" else alpha.height
    cross_size = alpha.height if axis == "x" else alpha.width
    if segments <= 1:
        return [0, size]
    pixels = list(alpha.get_flattened_data())
    occupancy: list[int] = []
    for position in range(size):
        if axis == "x":
            occupancy.append(
                sum(
                    1
                    for cross in range(cross_size)
                    if pixels[cross * alpha.width + position] > 8
                )
            )
        else:
            start = position * alpha.width
            occupancy.append(
                sum(1 for value in pixels[start : start + cross_size] if value > 8)
            )

    step = size / segments
    radius = max(2, round(step * 0.35))
    boundaries = [0]
    for index in range(1, segments):
        expected = round(index * step)
        lower = max(boundaries[-1] + 1, expected - radius)
        upper = min(size - 1, expected + radius)
        boundary = min(
            range(lower, upper + 1),
            key=lambda position: (occupancy[position], abs(position - expected)),
        )
        boundaries.append(boundary)
    boundaries.append(size)
    return boundaries


def extract_sheet(
    source: Path,
    output_dir: Path,
    columns: int,
    rows: int,
    names: list[str],
) -> None:
    sheet = Image.open(source).convert("RGBA")
    if columns <= 0 or rows <= 0 or len(names) != columns * rows:
        raise ValueError("grid size must match the number of output names")
    keyed_sheet = _remove_green(sheet, 18.0, 96.0)
    x_boundaries = _find_boundaries(keyed_sheet.getchannel("A"), columns, "x")
    y_boundaries = _find_boundaries(keyed_sheet.getchannel("A"), rows, "y")
    output_dir.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(names):
        column = index % columns
        row = index // columns
        keyed = keyed_sheet.crop(
            (
                x_boundaries[column],
                y_boundaries[row],
                x_boundaries[column + 1],
                y_boundaries[row + 1],
            )
        )
        normalized = _normalize_canvas(keyed, 256, 16)
        normalized.save(output_dir / f"{name}.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--columns", type=int, required=True)
    parser.add_argument("--rows", type=int, default=1)
    parser.add_argument("--names", required=True)
    args = parser.parse_args()
    extract_sheet(
        args.source,
        args.output_dir,
        args.columns,
        args.rows,
        args.names.split(","),
    )


if __name__ == "__main__":
    main()
