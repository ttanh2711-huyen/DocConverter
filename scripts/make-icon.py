"""Vẽ icon DocConverter (1024×1024) rồi tạo AppIcon.icns: uv run --project core python scripts/make-icon.py"""

import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "app" / "Resources" / "AppIcon.icns"


def draw(size: int = 1024) -> Image.Image:
    s = size / 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([80 * s, 80 * s, 944 * s, 944 * s], radius=190 * s, fill=(30, 94, 196))
    # tờ PDF (đỏ) phía sau, tờ văn bản (trắng) phía trước
    d.rounded_rectangle([210 * s, 190 * s, 600 * s, 700 * s], radius=36 * s, fill=(214, 64, 52))
    d.rounded_rectangle([420 * s, 330 * s, 820 * s, 840 * s], radius=36 * s, fill=(255, 255, 255))
    for i in range(5):
        y = (430 + i * 75) * s
        d.rounded_rectangle([480 * s, y, (760 if i % 2 == 0 else 700) * s, y + 26 * s], radius=13 * s, fill=(30, 94, 196))
    # mũi tên chuyển đổi
    d.polygon([(250 * s, 760 * s), (380 * s, 760 * s), (380 * s, 715 * s), (460 * s, 795 * s),
               (380 * s, 875 * s), (380 * s, 830 * s), (250 * s, 830 * s)], fill=(255, 210, 63))
    return img


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        big = draw()
        for px in (16, 32, 128, 256, 512):
            big.resize((px, px), Image.LANCZOS).save(iconset / f"icon_{px}x{px}.png")
            big.resize((px * 2, px * 2), Image.LANCZOS).save(iconset / f"icon_{px}x{px}@2x.png")
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(OUT)], check=True)
    print("Đã tạo", OUT)


if __name__ == "__main__":
    main()
