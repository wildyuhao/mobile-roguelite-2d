from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image


KEY_GREEN = (0, 255, 0)


def _alpha_for_color(
    red: int,
    green: int,
    blue: int,
    source_alpha: int,
    inner: float,
    outer: float,
) -> int:
    distance = math.sqrt(
        (red - KEY_GREEN[0]) ** 2
        + (green - KEY_GREEN[1]) ** 2
        + (blue - KEY_GREEN[2]) ** 2
    )
    if distance <= inner:
        return 0
    if distance >= outer:
        return source_alpha
    blend = (distance - inner) / max(1.0, outer - inner)
    return round(source_alpha * blend)


def _remove_green(image: Image.Image, inner: float, outer: float) -> Image.Image:
    rgba = image.convert("RGBA")
    output = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    pixels = []
    for red, green, blue, alpha in rgba.get_flattened_data():
        keyed_alpha = _alpha_for_color(red, green, blue, alpha, inner, outer)
        if keyed_alpha < alpha:
            green = min(green, max(red, blue))
        pixels.append((red, green, blue, keyed_alpha))
    output.putdata(pixels)
    return output


def _normalize_canvas(image: Image.Image, canvas_size: int, padding: int) -> Image.Image:
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError("Chroma-key output contains no visible subject")
    subject = image.crop(bounds)
    available = max(1, canvas_size - padding * 2)
    scale = min(available / subject.width, available / subject.height)
    width = max(1, round(subject.width * scale))
    height = max(1, round(subject.height * scale))
    subject = subject.resize((width, height), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.alpha_composite(subject, ((canvas_size - width) // 2, (canvas_size - height) // 2))
    return canvas


def process_image(
    input_path: Path,
    output_path: Path,
    inner: float = 18.0,
    outer: float = 96.0,
    canvas_size: int = 256,
    padding: int = 12,
) -> None:
    if inner < 0.0 or outer <= inner:
        raise ValueError("outer tolerance must be greater than inner tolerance")
    if canvas_size <= padding * 2:
        raise ValueError("canvas size must be larger than twice the padding")
    image = Image.open(input_path)
    keyed = _remove_green(image, inner, outer)
    normalized = _normalize_canvas(keyed, canvas_size, padding)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    normalized.save(output_path)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove a flat green screen and normalize a game asset canvas."
    )
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--inner", type=float, default=18.0)
    parser.add_argument("--outer", type=float, default=96.0)
    parser.add_argument("--canvas-size", type=int, default=256)
    parser.add_argument("--padding", type=int, default=12)
    arguments = parser.parse_args()
    process_image(
        arguments.input,
        arguments.output,
        inner=arguments.inner,
        outer=arguments.outer,
        canvas_size=arguments.canvas_size,
        padding=arguments.padding,
    )


if __name__ == "__main__":
    main()
