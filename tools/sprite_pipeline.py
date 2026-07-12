from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def _normalize_frame(
    frame: Image.Image,
    target_size: int,
    foot_y: int,
    padding: int,
) -> tuple[Image.Image, tuple[int, int, int, int]]:
    rgba = frame.convert("RGBA")
    bounds = rgba.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Contact sheet contains an empty frame")

    subject = rgba.crop(bounds)
    available_width = target_size - padding * 2
    available_height = foot_y - padding
    scale = min(
        available_width / subject.width,
        available_height / subject.height,
    )
    width = max(1, round(subject.width * scale))
    height = max(1, round(subject.height * scale))
    subject = subject.resize((width, height), Image.Resampling.NEAREST)

    output = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    x = (target_size - width) // 2
    y = foot_y - height
    output.alpha_composite(subject, (x, y))
    normalized_bounds = output.getchannel("A").getbbox()
    if normalized_bounds is None:
        raise ValueError("Normalized frame contains no visible pixels")
    return output, normalized_bounds


def process_sheet(
    input_path: Path,
    output_path: Path,
    columns: int = 3,
    rows: int = 2,
    target_size: int = 128,
    foot_y: int = 112,
    padding: int = 8,
) -> dict:
    if columns <= 0 or rows <= 0:
        raise ValueError("columns and rows must be positive")
    if target_size <= 0 or foot_y <= padding or foot_y > target_size:
        raise ValueError("target size, foot position, and padding are inconsistent")

    sheet = Image.open(input_path).convert("RGBA")
    if sheet.width % columns != 0 or sheet.height % rows != 0:
        raise ValueError("contact sheet dimensions must divide evenly by the grid")

    cell_width = sheet.width // columns
    cell_height = sheet.height // rows
    frames: list[Image.Image] = []
    widths: list[int] = []
    heights: list[int] = []
    for row in range(rows):
        for column in range(columns):
            cell = sheet.crop(
                (
                    column * cell_width,
                    row * cell_height,
                    (column + 1) * cell_width,
                    (row + 1) * cell_height,
                )
            )
            frame, bounds = _normalize_frame(cell, target_size, foot_y, padding)
            frames.append(frame)
            widths.append(bounds[2] - bounds[0])
            heights.append(bounds[3] - bounds[1])

    strip = Image.new(
        "RGBA",
        (target_size * len(frames), target_size),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * target_size, 0))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output_path)
    return {
        "frame_count": len(frames),
        "frame_size": target_size,
        "foot_y": foot_y,
        "widths": widths,
        "heights": heights,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Split and normalize an animation contact sheet."
    )
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--columns", type=int, default=3)
    parser.add_argument("--rows", type=int, default=2)
    parser.add_argument("--target-size", type=int, default=128)
    parser.add_argument("--foot-y", type=int, default=112)
    parser.add_argument("--padding", type=int, default=8)
    arguments = parser.parse_args()
    report = process_sheet(
        arguments.input,
        arguments.output,
        columns=arguments.columns,
        rows=arguments.rows,
        target_size=arguments.target_size,
        foot_y=arguments.foot_y,
        padding=arguments.padding,
    )
    print(report)


if __name__ == "__main__":
    main()
