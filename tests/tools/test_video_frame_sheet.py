from pathlib import Path
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.video_frame_sheet import (
    build_sheet,
    select_frame_indices,
    select_ping_pong_indices,
)


class VideoFrameSheetTests(unittest.TestCase):
    def test_selects_even_frames_without_duplicate_endpoint(self) -> None:
        indices = select_frame_indices(121, 16)

        self.assertEqual(len(indices), 16)
        self.assertEqual(indices[0], 0)
        self.assertEqual(indices[-1], 113)
        self.assertEqual(len(set(indices)), 16)

    def test_builds_sheet_in_source_order(self) -> None:
        frames = [
            Image.new("RGB", (2, 3), color)
            for color in [(10, 20, 30), (40, 50, 60), (70, 80, 90)]
        ]

        sheet = build_sheet(frames, columns=2)

        self.assertEqual(sheet.size, (4, 6))
        self.assertEqual(sheet.getpixel((0, 0)), (10, 20, 30))
        self.assertEqual(sheet.getpixel((2, 0)), (40, 50, 60))
        self.assertEqual(sheet.getpixel((0, 3)), (70, 80, 90))
        self.assertEqual(sheet.getpixel((2, 3)), (10, 20, 30))

    def test_selects_symmetric_ping_pong_cycle(self) -> None:
        indices = select_ping_pong_indices(121, 16)

        self.assertEqual(
            indices,
            [0, 8, 15, 23, 30, 38, 45, 53, 60, 53, 45, 38, 30, 23, 15, 8],
        )
        self.assertEqual(abs(indices[-1] - indices[0]), 8)
        self.assertEqual(abs(indices[8] - indices[9]), 7)


if __name__ == "__main__":
    unittest.main()
