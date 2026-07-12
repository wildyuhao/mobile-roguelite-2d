from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def checker(size: tuple[int, int], block: int = 12) -> Image.Image:
    image = Image.new("RGBA", size, "white")
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], block):
        for x in range(0, size[0], block):
            if (x // block + y // block) % 2:
                draw.rectangle(
                    (x, y, x + block - 1, y + block - 1),
                    fill=(218, 218, 218, 255),
                )
    return image


def build(background: Path, output: Path, assets: list[Path]) -> None:
    if len(assets) > 20:
        raise ValueError("contact sheet supports at most 20 assets")
    canvas = (
        Image.open(background)
        .convert("RGB")
        .resize((720, 1280), Image.Resampling.LANCZOS)
        .convert("RGBA")
    )
    draw = ImageDraw.Draw(canvas)
    columns = 5
    cell_width, cell_height = 136, 286
    for index, path in enumerate(assets):
        column, row = index % columns, index // columns
        x, y = 12 + column * cell_width, 48 + row * cell_height
        panel = checker((124, 230))
        asset = Image.open(path).convert("RGBA")
        asset.thumbnail((112, 196), Image.Resampling.LANCZOS)
        panel.alpha_composite(
            asset,
            ((124 - asset.width) // 2, (210 - asset.height) // 2),
        )
        canvas.alpha_composite(panel, (x, y))
        draw.text(
            (x, y + 236),
            path.stem[:20],
            fill="white",
            stroke_width=2,
            stroke_fill="black",
        )
    draw.text(
        (12, 12),
        f"Modular weapons: {len(assets)} assets",
        fill="white",
        stroke_width=2,
        stroke_fill="black",
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--background", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("assets", type=Path, nargs="+")
    args = parser.parse_args()
    build(args.background, args.output, args.assets)


if __name__ == "__main__":
    main()
