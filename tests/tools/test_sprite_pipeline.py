from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.sprite_pipeline import process_sheet


class SpritePipelineTests(unittest.TestCase):
    def test_splits_six_frames_and_aligns_feet(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "contact_sheet.png"
            output = Path(directory) / "walk_strip.png"
            image = Image.new("RGBA", (300, 200), (0, 0, 0, 0))
            draw = ImageDraw.Draw(image)
            for index in range(6):
                column = index % 3
                row = index // 3
                left = column * 100 + 30 + index % 2
                top = row * 100 + 15 + index % 3
                draw.rectangle(
                    (left, top, left + 39, top + 69),
                    fill=(80 + index * 20, 40, 180, 255),
                )
                if index == 0:
                    draw.rectangle(
                        (left, 95, left + 5, 99),
                        fill=(255, 255, 255, 255),
                    )
            image.save(source)

            report = process_sheet(
                source,
                output,
                columns=3,
                rows=2,
                target_size=128,
                foot_y=112,
                padding=8,
            )

            strip = Image.open(output).convert("RGBA")
            self.assertEqual(strip.size, (768, 128))
            self.assertEqual(report["frame_count"], 6)
            self.assertEqual(report["foot_y"], 112)
            for index in range(6):
                frame = strip.crop((index * 128, 0, (index + 1) * 128, 128))
                bounds = frame.getchannel("A").getbbox()
                self.assertIsNotNone(bounds)
                self.assertEqual(bounds[3], 112)
                foot_row = frame.getchannel("A").crop((0, 111, 128, 112))
                foot_coverage = sum(
                    1 for value in foot_row.get_flattened_data() if value > 0
                )
                self.assertGreater(foot_coverage, 20)
                self.assertLessEqual(
                    abs((bounds[2] - bounds[0]) - report["widths"][0]),
                    4,
                )


if __name__ == "__main__":
    unittest.main()
