from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image


def select_frame_indices(frame_count: int, frame_total: int) -> list[int]:
    if frame_count <= 0:
        raise ValueError("video must contain at least one frame")
    if frame_total <= 0:
        raise ValueError("frame total must be positive")
    if frame_total > frame_count:
        raise ValueError("frame total cannot exceed decoded video frames")
    return [int(index * frame_count / frame_total) for index in range(frame_total)]


def select_ping_pong_indices(frame_count: int, frame_total: int) -> list[int]:
    if frame_count <= 0:
        raise ValueError("video must contain at least one frame")
    if frame_total < 4 or frame_total % 2 != 0:
        raise ValueError("ping-pong frame total must be an even number of at least four")

    forward_count = frame_total // 2 + 1
    midpoint = (frame_count - 1) // 2
    if forward_count > midpoint + 1:
        raise ValueError("video does not contain enough frames for ping-pong sampling")
    forward = [
        int(index * midpoint / (forward_count - 1) + 0.5)
        for index in range(forward_count)
    ]
    return forward + list(reversed(forward[1:-1]))


def build_sheet(frames: list[Image.Image], columns: int) -> Image.Image:
    if not frames:
        raise ValueError("at least one frame is required")
    if columns <= 0:
        raise ValueError("columns must be positive")

    normalized = [frame.convert("RGB") for frame in frames]
    frame_size = normalized[0].size
    if any(frame.size != frame_size for frame in normalized):
        raise ValueError("all frames must have identical dimensions")

    rows = math.ceil(len(normalized) / columns)
    key_color = normalized[0].getpixel((0, 0))
    sheet = Image.new(
        "RGB",
        (frame_size[0] * columns, frame_size[1] * rows),
        key_color,
    )
    for index, frame in enumerate(normalized):
        x = (index % columns) * frame_size[0]
        y = (index // columns) * frame_size[1]
        sheet.paste(frame, (x, y))
    return sheet


def extract_video_sheet(
    input_path: Path,
    output_path: Path,
    frame_total: int = 16,
    columns: int = 4,
    ping_pong: bool = False,
) -> dict:
    try:
        import cv2
    except ImportError as error:
        raise RuntimeError(
            "OpenCV is required for MP4 decoding; install opencv-python-headless"
        ) from error

    capture = cv2.VideoCapture(str(input_path.resolve()))
    if not capture.isOpened():
        raise ValueError(f"could not open video: {input_path}")

    source_frame_count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    source_fps = float(capture.get(cv2.CAP_PROP_FPS))
    indices = (
        select_ping_pong_indices(source_frame_count, frame_total)
        if ping_pong
        else select_frame_indices(source_frame_count, frame_total)
    )
    frames: list[Image.Image] = []
    for frame_index in indices:
        capture.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
        decoded, bgr_frame = capture.read()
        if not decoded:
            capture.release()
            raise ValueError(f"could not decode video frame {frame_index}")
        rgb_frame = cv2.cvtColor(bgr_frame, cv2.COLOR_BGR2RGB)
        frames.append(Image.fromarray(rgb_frame))
    capture.release()

    sheet = build_sheet(frames, columns)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)
    return {
        "source_frames": source_frame_count,
        "source_fps": source_fps,
        "source_duration": (
            source_frame_count / source_fps if source_fps > 0.0 else 0.0
        ),
        "selected_indices": indices,
        "frame_count": len(frames),
        "loop_mode": "ping_pong" if ping_pong else "natural",
        "columns": columns,
        "rows": math.ceil(len(frames) / columns),
        "sheet_size": list(sheet.size),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sample an MP4 into a contact sheet for the sprite pipeline."
    )
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--frames", type=int, default=16)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--ping-pong", action="store_true")
    arguments = parser.parse_args()
    report = extract_video_sheet(
        arguments.input,
        arguments.output,
        frame_total=arguments.frames,
        columns=arguments.columns,
        ping_pong=arguments.ping_pong,
    )
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
