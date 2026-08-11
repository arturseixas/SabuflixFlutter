#!/usr/bin/env python3
"""Generates the launcher art the TV platforms ask for.

Android TV wants a 320x180 banner, Tizen a 117x117 icon, webOS an 80x80 icon
plus a 130x130 large icon and a 1920x1080 splash. They are all the same mark —
the Sabuflix wordmark, white on black, over the accent blue — so they are drawn
here from one description instead of being hand-exported five times.

Run from the repository root:

    python3 tools/generate_tv_art.py

Requires Pillow (`pip install pillow`) and only needs to be re-run when the
brand mark changes; the generated files are committed.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BACKGROUND = (0, 0, 0, 255)
ACCENT = (10, 132, 255, 255)  # SabuflixTheme.accent
WHITE = (255, 255, 255, 255)

FONT_CANDIDATES = [
    "/mnt/skills/examples/canvas-design/canvas-fonts/Outfit-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]


def load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    raise SystemExit("No usable font found; install DejaVu or adjust FONT_CANDIDATES.")


def accent_glow(image, center, radius):
    """A soft blue bloom behind the mark, drawn as concentric alpha rings."""
    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    steps = 26
    for i in range(steps, 0, -1):
        r = radius * i / steps
        alpha = int(46 * (1 - i / steps) ** 1.6)
        draw.ellipse(
            [center[0] - r, center[1] - r, center[0] + r, center[1] + r],
            fill=(ACCENT[0], ACCENT[1], ACCENT[2], alpha),
        )
    return Image.alpha_composite(image, glow)


def wordmark(size, text, font_ratio, with_glow=True, accent_bar=False):
    width, height = size
    image = Image.new("RGBA", size, BACKGROUND)
    if with_glow:
        image = accent_glow(image, (width * 0.5, height * 0.55), width * 0.75)

    draw = ImageDraw.Draw(image)
    font = load_font(max(8, int(height * font_ratio)))
    box = draw.textbbox((0, 0), text, font=font)
    text_width = box[2] - box[0]
    text_height = box[3] - box[1]
    draw.text(
        ((width - text_width) / 2 - box[0], (height - text_height) / 2 - box[1]),
        text,
        font=font,
        fill=WHITE,
    )

    if accent_bar:
        bar_width = width * 0.18
        bar_height = max(3, height * 0.022)
        top = height * 0.5 + text_height * 0.9
        draw.rounded_rectangle(
            [(width - bar_width) / 2, top, (width + bar_width) / 2, top + bar_height],
            radius=bar_height / 2,
            fill=ACCENT,
        )

    return image.convert("RGB") if size[0] > 400 else image


def write(image, relative_path):
    path = os.path.join(ROOT, relative_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, "PNG")
    print("wrote", relative_path)


def main():
    # Android TV / Google TV launcher banner.
    write(
        wordmark((320, 180), "Sabuflix", 0.19, accent_bar=True),
        "android/app/src/main/res/drawable-xhdpi/tv_banner.png",
    )

    # Samsung Tizen application icon.
    write(wordmark((117, 117), "S", 0.55), "tv/tizen/icon.png")

    # LG webOS icons.
    write(wordmark((80, 80), "S", 0.55), "tv/webos/icon.png")
    write(wordmark((130, 130), "S", 0.55), "tv/webos/largeIcon.png")

    # Shared 16:9 splash, used by both TV packages while the engine boots.
    splash = wordmark((1920, 1080), "Sabuflix", 0.11, accent_bar=True)
    write(splash, "tv/webos/splash.png")
    write(splash, "tv/tizen/splash.png")

    return 0


if __name__ == "__main__":
    sys.exit(main())
