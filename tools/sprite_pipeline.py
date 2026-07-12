from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def _retain_largest_alpha_component(frame: Image.Image) -> Image.Image:
    rgba = frame.convert("RGBA")
    width, height = rgba.size
    alpha_values = rgba.getchannel("A").tobytes()
    active = bytearray(1 if value > 0 else 0 for value in alpha_values)
    visited = bytearray(len(active))
    largest: list[int] = []

    for seed, is_active in enumerate(active):
        if not is_active or visited[seed]:
            continue

        component: list[int] = []
        stack = [seed]
        visited[seed] = 1
        while stack:
            current = stack.pop()
            component.append(current)
            y, x = divmod(current, width)
            for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
                row_offset = neighbor_y * width
                for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                    neighbor = row_offset + neighbor_x
                    if active[neighbor] and not visited[neighbor]:
                        visited[neighbor] = 1
                        stack.append(neighbor)

        if len(component) > len(largest):
            largest = component

    if not largest:
        raise ValueError("Contact sheet contains an empty frame")

    cleaned_alpha = bytearray(len(alpha_values))
    for index in largest:
        cleaned_alpha[index] = alpha_values[index]
    rgba.putalpha(Image.frombytes("L", (width, height), bytes(cleaned_alpha)))
    return rgba


def _normalize_frame(
    frame: Image.Image,
    target_size: int,
    foot_y: int,
    padding: int,
) -> tuple[Image.Image, tuple[int, int, int, int]]:
    rgba = _retain_largest_alpha_component(frame)
    bounds = rgba.getchannel("A").getbbox()
    assert bounds is not None

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
