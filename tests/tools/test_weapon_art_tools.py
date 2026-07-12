from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.build_weapon_contact_sheet import build
from tools.extract_green_sheet import extract_sheet


class WeaponArtToolTests(unittest.TestCase):
    def test_extracts_named_cells_to_transparent_normalized_canvases(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "sheet.png"
            output = root / "output"
            sheet = Image.new("RGBA", (200, 100), (0, 255, 0, 255))
            draw = ImageDraw.Draw(sheet)
            draw.rectangle((30, 20, 110, 80), fill=(220, 50, 80, 255))
            draw.ellipse((130, 25, 175, 75), fill=(60, 120, 240, 255))
            sheet.save(source)

            extract_sheet(source, output, 2, 1, ["blade", "flame"])

            for name in ["blade", "flame"]:
                result = Image.open(output / f"{name}.png").convert("RGBA")
                self.assertEqual(result.size, (256, 256))
                self.assertEqual(result.getpixel((0, 0))[3], 0)
                self.assertIsNotNone(result.getchannel("A").getbbox())
            flame = Image.open(output / "flame.png").convert("RGBA")
            red_pixels = [
                pixel
                for pixel in flame.get_flattened_data()
                if pixel[3] > 128 and pixel[0] > 150 and pixel[2] < 120
            ]
            self.assertFalse(red_pixels, "adaptive split should reject the prior cell")

    def test_builds_fixed_portrait_contact_sheet(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            background = root / "background.png"
            first = root / "first.png"
            second = root / "second.png"
            output = root / "contact.png"
            Image.new("RGB", (64, 64), (35, 38, 42)).save(background)
            Image.new("RGBA", (32, 32), (255, 100, 30, 255)).save(first)
            Image.new("RGBA", (32, 32), (40, 190, 255, 180)).save(second)

            build(background, output, [first, second])

            result = Image.open(output).convert("RGB")
            self.assertEqual(result.size, (720, 1280))
            self.assertIsNotNone(result.getbbox())
            self.assertNotEqual(result.getpixel((20, 60)), result.getpixel((700, 1200)))


if __name__ == "__main__":
    unittest.main()
