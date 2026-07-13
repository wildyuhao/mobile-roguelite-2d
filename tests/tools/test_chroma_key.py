from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.chroma_key import _remove_green, process_image


class ChromaKeyTests(unittest.TestCase):
    def test_removes_green_preserves_subject_and_normalizes_canvas(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.png"
            output = Path(directory) / "output.png"
            image = Image.new("RGBA", (6, 4), (0, 255, 0, 255))
            image.putpixel((2, 1), (220, 40, 80, 255))
            image.putpixel((3, 1), (220, 40, 80, 255))
            image.putpixel((2, 2), (220, 40, 80, 255))
            image.putpixel((3, 2), (220, 40, 80, 255))
            image.save(source)

            process_image(source, output, inner=12.0, outer=72.0, canvas_size=32, padding=4)

            result = Image.open(output).convert("RGBA")
            self.assertEqual(result.size, (32, 32))
            self.assertEqual(result.getpixel((0, 0))[3], 0)
            self.assertGreater(result.getbbox()[2] - result.getbbox()[0], 0)
            opaque_pixels = [
                pixel for pixel in result.get_flattened_data() if pixel[3] == 255
            ]
            self.assertTrue(opaque_pixels)
            self.assertTrue(any(pixel[0] > pixel[1] for pixel in opaque_pixels))

    def test_removes_dark_green_antialias_spill(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.png"
            output = Path(directory) / "output.png"
            image = Image.new("RGBA", (8, 6), (0, 255, 0, 255))
            image.putpixel((2, 2), (28, 132, 20, 255))
            image.putpixel((3, 2), (52, 154, 42, 255))
            image.putpixel((4, 2), (220, 40, 80, 255))
            image.putpixel((4, 3), (220, 40, 80, 255))
            image.save(source)

            process_image(source, output, inner=12.0, outer=72.0, canvas_size=32, padding=4)

            result = Image.open(output).convert("RGBA")
            green_spill = [
                pixel
                for pixel in result.get_flattened_data()
                if pixel[3] > 8
                and pixel[1] > 100
                and pixel[1] > pixel[0] * 1.2
                and pixel[1] > pixel[2] * 1.2
            ]
            self.assertFalse(green_spill)

    def test_preserves_enclosed_green_subject_detail(self) -> None:
        image = Image.new("RGBA", (7, 7), (0, 255, 0, 255))
        for x in range(2, 5):
            image.putpixel((x, 2), (220, 40, 80, 255))
            image.putpixel((x, 4), (220, 40, 80, 255))
        for y in range(2, 5):
            image.putpixel((2, y), (220, 40, 80, 255))
            image.putpixel((4, y), (220, 40, 80, 255))
        image.putpixel((3, 3), (30, 100, 30, 255))

        result = _remove_green(image, inner=12.0, outer=72.0)

        self.assertEqual(result.getpixel((0, 0))[3], 0)
        self.assertEqual(result.getpixel((3, 3)), (30, 100, 30, 255))


if __name__ == "__main__":
    unittest.main()
