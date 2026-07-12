from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.chroma_key import process_image


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


if __name__ == "__main__":
    unittest.main()
